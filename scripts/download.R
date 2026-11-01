# Restores frozen bytes only if upstream still matches; never silently replaces data.
m<-jsonlite::fromJSON('data/input-manifest.json')
dir.create('data/raw',recursive=TRUE,showWarnings=FALSE)
for(i in seq_len(nrow(m$files))){f<-m$files[i,];dest<-file.path('data/raw',f$filename)
 if(file.exists(dest)){
  if(!identical(digest::digest(file=dest,algo='sha256'),f$sha256)) stop('Existing file differs: ',dest)
  next
 }
 tmp<-tempfile(fileext='.csv');download.file(f$url,tmp,mode='wb',method='libcurl')
 if(f$filename=='lookup_premise.csv'){
  x<-readr::read_csv(tmp,show_col_types=FALSE)
  readr::write_csv(x[c('premise_code','premise_type','state','district')],tmp)
 }
 if(!identical(digest::digest(file=tmp,algo='sha256'),f$sha256)) stop('Upstream snapshot changed: ',f$filename,'. Obtain the frozen snapshot; do not claim exact reproduction.')
 if(!file.copy(tmp,dest,overwrite=FALSE)) stop('Could not save ',dest)
 unlink(tmp)
}
source('scripts/verify_inputs.R')
