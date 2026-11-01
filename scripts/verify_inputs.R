m<-jsonlite::fromJSON('data/input-manifest.json')
for(i in seq_len(nrow(m$files))){f<-m$files[i,];p<-file.path('data/raw',f$filename)
 if(!file.exists(p)) stop('Missing input: ',p,call.=FALSE)
 if(!identical(digest::digest(file=p,algo='sha256'),f$sha256)) stop('Input checksum mismatch: ',p,call.=FALSE)
}
cat('All frozen input SHA-256 checks passed.\n')
