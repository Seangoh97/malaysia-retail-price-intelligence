# Restore the tested data/model snapshots bundled with this repository.
archive <- 'project-bundle.zip'
if (!file.exists(archive)) stop('Missing project-bundle.zip; download the full repository including its bundle.', call.=FALSE)
entries <- unzip(archive, list=TRUE)$Name
prefix <- 'malaysia-retail-price-intelligence/'
wanted <- entries[startsWith(entries,paste0(prefix,'data/raw/')) | entries==paste0(prefix,'results/model.rds')]
if (length(wanted)!=4) stop('Unexpected bundle layout',call.=FALSE)
staging <- tempfile('price-intelligence-');dir.create(staging)
unzip(archive,files=wanted,exdir=staging)
for (name in wanted) {
 target <- substring(name,nchar(prefix)+1)
 dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
 if (file.exists(target)) {
  if (!identical(tools::md5sum(file.path(staging,name))[[1]],tools::md5sum(target)[[1]])) stop('Existing snapshot differs: ',target,'. Preserve it before unpacking.',call.=FALSE)
 } else if (!file.copy(file.path(staging,name),target)) stop('Could not restore ',target,call.=FALSE)
}
unlink(staging,recursive=TRUE)
source('scripts/verify_inputs.R')
cat('Tested input snapshots and model restored.\n')
