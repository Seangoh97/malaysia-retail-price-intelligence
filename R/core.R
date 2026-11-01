suppressPackageStartupMessages(library(dplyr))
formats <- c('Hypermarket','Pasar Raya / Supermarket','Pasar Mini','Kedai Runcit','Pasar Basah')
format_names <- c('Hypermarket','Supermarket','Mini market','Sundry shop','Wet market')
required_packages <- c('dplyr','readr','sandwich','jsonlite','digest')
assert <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call.=FALSE)
check_columns <- function(x, cols, label) assert(all(cols %in% names(x)), paste(label,'missing columns:',paste(setdiff(cols,names(x)),collapse=', ')))
check_key <- function(x,key) assert(!anyNA(x[[key]]) && !anyDuplicated(x[[key]]),paste('Missing or duplicate lookup key:',key))
read_inputs <- function(raw, month) {
 p <- readr::read_csv(file.path(raw,paste0('pricecatcher_',month,'.csv')),show_col_types=FALSE)
 i <- readr::read_csv(file.path(raw,'lookup_item.csv'),show_col_types=FALSE)
 s <- readr::read_csv(file.path(raw,'lookup_premise.csv'),show_col_types=FALSE)
 check_columns(p,c('date','premise_code','item_code','price'),'Prices')
 check_columns(i,c('item_code','item','unit','item_group','item_category'),'Items')
 check_columns(s,c('premise_code','premise_type','state','district'),'Premises')
 assert(nrow(readr::problems(p))==0 && nrow(readr::problems(i))==0 && nrow(readr::problems(s))==0,'CSV parsing failures')
 check_key(i,'item_code');check_key(s,'premise_code')
 assert(is.numeric(p$price),'Price must be numeric')
 p$date <- as.Date(p$date)
 assert(!anyNA(p$date) && all(format(p$date,'%Y-%m')==month),'Dates outside requested month or invalid dates')
 assert(!anyNA(p$premise_code) && !anyNA(p$item_code),'Missing transaction keys')
 # Conflicting same-day quotes are rejected rather than silently averaged.
 duplicates <- p |> count(date,premise_code,item_code) |> filter(n>1)
 assert(nrow(duplicates)==0,'Duplicate date/premise/item observations; resolve upstream before modelling')
 i <- i |> mutate(across(where(is.character),trimws))
 s <- s |> mutate(across(where(is.character),trimws))
 valid_states <- c('Johor','Kedah','Kelantan','Melaka','Negeri Sembilan','Pahang','Pulau Pinang','Perak','Perlis','Selangor','Terengganu','Sabah','Sarawak','W.P. Kuala Lumpur','W.P. Labuan','W.P. Putrajaya')
 assert(all(na.omit(s$state) %in% valid_states),'Unrecognised state in lookup')
 audit <- list(raw_rows=nrow(p),invalid_price_rows=sum(!is.finite(p$price)|p$price<=0),
   unmatched_items=sum(!p$item_code %in% i$item_code),unmatched_premises=sum(!p$premise_code %in% s$premise_code))
 d <- p |> left_join(i,by='item_code') |>
  left_join(s |> select(premise_code,premise_type,state,district),by='premise_code') |>
  filter(is.finite(price),price>0,premise_type %in% formats,!is.na(item),!is.na(unit),!is.na(state)) |>
  mutate(format=format_names[match(premise_type,formats)],
    region=if_else(state %in% c('Sabah','Sarawak','W.P. Labuan'),'East Malaysia','Peninsular Malaysia'),
    group=case_when(item_group=='BARANGAN BERBUNGKUS'~'Packaged goods',item_group=='BARANGAN KERING'~'Dry produce',item_group=='BARANGAN SEGAR'~'Fresh produce',TRUE~NA_character_),
    log_price=log(price)) |> filter(!is.na(group))
 audit$retained_retail_rows <- nrow(d);audit$excluded_rows <- nrow(p)-nrow(d)
 list(data=d,audit=audit)
}
coverage_items <- function(d,min_quotes=30L,min_premises=3L) {
 cells <- d |> group_by(item_code,format,region) |>
  summarise(n=n(),premises=n_distinct(premise_code),.groups='drop')
 cells |> group_by(item_code) |> summarise(cells=n(),smallest=min(n),fewest_premises=min(premises),.groups='drop') |>
  filter(cells==10,smallest>=min_quotes,fewest_premises>=min_premises)
}
choose_basket <- function(train) {
 eligible <- coverage_items(train)
 counts <- train |> semi_join(eligible,by='item_code') |>
  count(group,item_category,item_code,item,unit,name='quotes')
 # Stable ties: numeric item code, then category text.
 winners <- counts |> arrange(desc(quotes),item_code) |> group_by(group,item_category) |> slice_head(n=1) |> ungroup()
 winners |> arrange(desc(quotes),item_category,item_code) |> group_by(group) |> slice_head(n=4) |> ungroup()
}
features <- function(d,levels_item=NULL) {
 d |> mutate(item_factor=factor(item_code,levels=levels_item),
  format=factor(format,levels=format_names),region=factor(region,levels=c('Peninsular Malaysia','East Malaysia')),
  east_dry=as.integer(region=='East Malaysia' & group=='Dry produce'),
  east_fresh=as.integer(region=='East Malaysia' & group=='Fresh produce'))
}
fit_model <- function(d) {
 m<-lm(log_price ~ item_factor + format*region + east_dry + east_fresh,data=d)
 assert(!anyNA(coef(m)),'Rank-deficient model; insufficient support')
 m
}
cluster_cov <- function(m,d) {
 assert(length(unique(d$premise_code))>=30,'Fewer than 30 premise clusters')
 sandwich::vcovCL(m,cluster=d$premise_code,type='HC1',cadjust=TRUE)
}
metrics <- function(m,train,test,label) {
 assert(nrow(test)>0,paste('Empty validation split:',label))
 pred<-as.numeric(predict(m,newdata=test))
 base<-train |> group_by(item_code) |> summarise(base=mean(log_price),.groups='drop')
 b<-base$base[match(test$item_code,base$item_code)]
 assert(all(is.finite(pred))&&all(is.finite(b)),'Nonfinite validation predictions')
 data.frame(split=label,rows=nrow(test),premises=n_distinct(test$premise_code),
  model_log_MAE=mean(abs(test$log_price-pred)),baseline_log_MAE=mean(abs(test$log_price-b)),
  model_log_RMSE=sqrt(mean((test$log_price-pred)^2)),baseline_log_RMSE=sqrt(mean((test$log_price-b)^2)),
  model_median_abs_percentage_error=100*median(abs(exp(pred)/test$price-1)),
  baseline_median_abs_percentage_error=100*median(abs(exp(b)/test$price-1)))
}
benchmark <- function(bundle,quotes) {
 check_columns(quotes,c('item_code','format','region','price'),'Quotes')
 assert(is.numeric(quotes$price)&&all(is.finite(quotes$price)&quotes$price>0),'Quote prices must be positive finite numbers')
 assert(all(quotes$format %in% format_names),'Unsupported retail format')
 assert(all(quotes$region %in% c('Peninsular Malaysia','East Malaysia')),'Unsupported region')
 assert(all(quotes$item_code %in% bundle$items$item_code),'Unsupported item code; inspect results/basket.csv')
 d<-quotes |> left_join(bundle$items |> select(item_code,item,unit,group),by='item_code')
 d<-features(d,bundle$model$xlevels$item_factor)
 x<-model.matrix(delete.response(terms(bundle$model)),d,contrasts.arg=bundle$model$contrasts)
 x<-x[,names(coef(bundle$model)),drop=FALSE]
 est<-as.numeric(x %*% coef(bundle$model)); se<-sqrt(pmax(0,rowSums((x %*% bundle$vcov)*x)))
 crit<-qt(.975,bundle$clusters-1)
 data.frame(item_code=d$item_code,item=d$item,unit=d$unit,format=d$format,region=d$region,quoted_price=d$price,
  benchmark_geometric_price=exp(est),mean_CI_low=exp(est-crit*se),mean_CI_high=exp(est+crit*se),
  quote_vs_benchmark_pct=100*(d$price/exp(est)-1),reference_month=bundle$month,
  note='Conditional geometric mean; CI is not an individual-price prediction interval')
}
