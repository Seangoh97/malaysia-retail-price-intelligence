# Keep renv bookkeeping inside the project for restricted environments.
if (!nzchar(Sys.getenv('RENV_PATHS_ROOT'))) Sys.setenv(RENV_PATHS_ROOT=file.path(getwd(),'renv','local'))
if (!nzchar(Sys.getenv('RENV_PATHS_SANDBOX'))) Sys.setenv(RENV_PATHS_SANDBOX=file.path(getwd(),'renv','local','sandbox'))
source('renv/activate.R')
