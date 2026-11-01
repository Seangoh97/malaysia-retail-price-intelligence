args<-commandArgs(TRUE);month<-if(length(args)) args[1] else '2026-07'
source('R/core.R')
if (month == '2026-07') source('scripts/verify_inputs.R')
assert(grepl('^[0-9]{4}-(0[1-9]|1[0-2])$',month),'Month must be YYYY-MM')
for(p in required_packages) assert(requireNamespace(p,quietly=TRUE),paste('Missing package:',p))
dir.create('results',showWarnings=FALSE)
inputs<-read_inputs('data/raw',month);d<-inputs$data
# Predefined holdout rule: premise codes divisible by five never enter development.
cutoff<-as.Date(paste0(month,'-24'))
dev<-d |> filter(date<=cutoff,premise_code%%5!=0)
basket<-choose_basket(dev)
assert(nrow(basket)>=3 && length(unique(basket$group))==3,'Insufficient coverage for all three product groups')
d<-d |> semi_join(basket,by='item_code');d<-features(d,sort(basket$item_code))
train<-d |> filter(date<=cutoff,premise_code%%5!=0)
later<-d |> filter(date>cutoff,premise_code %in% train$premise_code)
newprem<-d |> filter(date>cutoff,premise_code%%5==0)
assert(!any(newprem$premise_code %in% train$premise_code),'Premise leakage')
assert(max(train$date)<min(later$date) && max(train$date)<min(newprem$date),'Temporal leakage')
m<-fit_model(train)
validation<-bind_rows(metrics(m,train,later,'Later dates / known premises'),metrics(m,train,newprem,'Later dates / held-out premises'))
# Operational snapshot refit uses all July observations for this frozen basket.
final<-fit_model(d);vc<-cluster_cov(final,d);clusters<-n_distinct(d$premise_code)
bundle<-list(model=final,vcov=vc,clusters=clusters,month=month,
 items=basket |> select(item_code,item,unit,group),cutoff=cutoff)
saveRDS(bundle,'results/model.rds')
readr::write_csv(basket,'results/basket.csv');readr::write_csv(validation,'results/validation.csv')
ct<-data.frame(term=names(coef(final)),estimate=unname(coef(final)),cluster_SE=sqrt(diag(vc)))
ct$p_value<-2*pt(-abs(ct$estimate/ct$cluster_SE),df=clusters-1)
ct$low<-ct$estimate-qt(.975,clusters-1)*ct$cluster_SE;ct$high<-ct$estimate+qt(.975,clusters-1)*ct$cluster_SE
readr::write_csv(ct,'results/coefficients.csv')
# All supported item-format-region combinations, plus observed descriptive ranges.
grid<-expand.grid(item_code=basket$item_code,format=format_names,region=c('Peninsular Malaysia','East Malaysia'),stringsAsFactors=FALSE)
grid$price<-1
bench<-benchmark(bundle,grid) |> select(-quoted_price,-quote_vs_benchmark_pct)
observed<-d |> group_by(item_code,format,region) |> summarise(quotes=n(),premises=n_distinct(premise_code),
 observed_median=median(price),observed_p10=quantile(price,.1),observed_p90=quantile(price,.9),.groups='drop')
bench<-bench |> mutate(format=as.character(format),region=as.character(region)) |> left_join(observed,by=c('item_code','format','region'))
readr::write_csv(bench,'results/benchmarks.csv')
# Sensitivity only: do not label low prices as errors or remove them from final fit.
trim<-d[abs(rstandard(final))<=4,];trim_fit<-fit_model(trim)
sens<-data.frame(term=names(coef(final)),full=coef(final),sensitivity=coef(trim_fit))
sens$delta_log_coefficient<-sens$sensitivity-sens$full
readr::write_csv(sens,'results/sensitivity.csv')
paths<-file.path('data/raw',c(paste0('pricecatcher_',month,'.csv'),'lookup_item.csv','lookup_premise.csv'))
manifest<-lapply(paths,function(p)list(path=p,sha256=digest::digest(file=p,algo='sha256'),bytes=file.info(p)$size))
jsonlite::write_json(list(month=month,created_utc=format(Sys.time(),tz='UTC',usetz=TRUE),inputs=manifest,
 audit=inputs$audit,model_rows=nrow(d),clusters=clusters,development_rows=nrow(train),
 item_count=nrow(basket),training_cutoff=as.character(cutoff),adjusted_R2=summary(final)$adj.r.squared,
 extreme_residuals=sum(abs(rstandard(final))>4),validation=validation),
 'results/run-manifest.json',pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),'results/session-info.txt')
# Small offline report; values come directly from this run.
html_table<-function(x){
 esc<-function(v){v<-gsub('&','&amp;',as.character(v),fixed=TRUE);gsub('<','&lt;',v,fixed=TRUE)}
 paste0('<table><tr>',paste0('<th>',esc(names(x)),'</th>',collapse=''),'</tr>',paste(apply(x,1,function(a)paste0('<tr>',paste0('<td>',esc(a),'</td>',collapse=''),'</tr>')),collapse=''),'</table>')}
writeLines(paste0('<!doctype html><html lang="en"><meta charset="utf-8"><title>Malaysia Retail Price Intelligence</title><style>body{font:16px system-ui;max-width:1200px;margin:40px auto;padding:20px;color:#183042}table{border-collapse:collapse;font-size:13px;display:block;overflow:auto}th,td{border:1px solid #ccd;padding:8px;text-align:left}th{background:#edf4f8}</style><h1>Malaysia Retail Price Intelligence</h1><p>Reference month: ',month,'. Conditional price benchmarks for a selected supported basket.</p><p>Historical decision-support prototype. These are geometric mean benchmarks, not forecasts, causal effects or recommended selling prices. Lookup snapshots postdate July. Confirm item units and current conditions before use.</p><h2>Validation</h2><p>Training: days 1–24, excluding premises with code divisible by five. Item selection uses training data only. Baseline: training item mean log price. Lower errors are better. Final benchmarks refit on all July data; validation pertains to the development model.</p>',html_table(validation),'<h2>Basket</h2>',html_table(basket),'<h2>Benchmarks (first 30 cells)</h2><p>Full supported-cell output: benchmarks.csv. Confidence intervals concern conditional geometric means; they do not describe the likely range of an individual quote. Standard errors cluster by premise; common date or district shocks may remain.</p>',html_table(head(bench,30)),'<p>See README.md and docs/model-card.md for use and limitations.</p></html>'),'results/report.html')
print(validation);cat('Completed:',nrow(d),'observations;',clusters,'premises. Outputs: results/\n')
