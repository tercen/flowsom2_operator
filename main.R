library(tercen)
library(dplyr)
library(flowCore)
library(FlowSOM)

save_rds <- function(object, filename, ctx) {
  
  workflowId <- getOption("tercen.workflowId") #ctx$workflowId
  stepId <- getOption("tercen.stepId") #ctx$stepId
  workflow <- ctx$client$workflowService$get(workflowId)
  
  fileDoc = FileDocument$new()
  fileDoc$name = filename
  fileDoc$projectId = workflow$projectId
  fileDoc$acl$owner = workflow$acl$owner
  fileDoc$metadata$contentType = 'application/octet-stream'
  
  metaWorkflowId = Pair$new()
  metaWorkflowId$key = 'workflow.id'
  metaWorkflowId$value = workflowId
  
  metaStepId = Pair$new()
  metaStepId$key = 'step.id'
  metaStepId$value = stepId
  
  fileDoc$meta = list(metaWorkflowId, metaStepId)
  
  con = rawConnection(raw(0), "r+")
  saveRDS(object, file = con)
  bytes = rawConnectionValue(con)
  
  fileDoc = ctx$client$fileService$upload(fileDoc, bytes)
  return(fileDoc$id)
}

get_FlowSOM_Clusters <- function(data, ctx) {
  colnames(data) <- ctx$rselect()[[1]]
  
  flow.dat <- flowCore::flowFrame(as.matrix(data))
  
  n.clust <- NULL
  if(!is.null(ctx$op.value('nclust')) && !ctx$op.value('nclust') == "NULL") n.clust <- as.integer(ctx$op.value('nclust'))
  
  seed <- NULL
  if(!is.null(ctx$op.value('seed')) && !ctx$op.value('seed') == "NULL") seed <- as.integer(ctx$op.value('seed'))
  
  xdim   = ifelse(is.null(ctx$op.value('xdim')), 10, as.integer(ctx$op.value('xdim')))
  ydim   = ifelse(is.null(ctx$op.value('ydim')), 10, as.integer(ctx$op.value('ydim')))
  rlen   = ifelse(is.null(ctx$op.value('rlen')), 10, as.integer(ctx$op.value('rlen')))
  mst    = ifelse(is.null(ctx$op.value('mst')), 1, as.integer(ctx$op.value('mst')))
  alpha  = c(
    ifelse(is.null(ctx$op.value('alpha_1')), 0.05, as.double(ctx$op.value('alpha_1'))),
    ifelse(is.null(ctx$op.value('alpha_2')), 0.01, as.double(ctx$op.value('alpha_2')))
  )
  distf  = ifelse(is.null(ctx$op.value('distf')), 2, as.integer(ctx$op.value('distf')))
  maxMeta  = ifelse(is.null(ctx$op.value('maxMeta')), 10, as.integer(ctx$op.value('maxMeta')))
  
  fsom <- FlowSOM(
    input = flow.dat,
    compensate = FALSE,
    colsToUse = 1:ncol(flow.dat),
    nClus = n.clust,
    maxMeta = maxMeta,
    seed = seed,
    xdim = xdim,
    ydim = ydim, 
    rlen = rlen, 
    mst = mst, 
    alpha = alpha,
    distf = distf
  )
  
  fname <- paste0("FlowSOM_model")
  model_documentId <- save_rds(fsom, fname, ctx)
  df_out <- data.frame(
    cluster_id = as.character(fsom[[2]][fsom[[1]]$map$mapping[, 1]]),
    model_documentId = model_documentId
  )
  return(df_out)
}

ctx <- tercenCtx()

ctx %>% 
  as.matrix() %>%
  t() %>%
  get_FlowSOM_Clusters(., ctx) %>%
  as_tibble() %>%
  mutate(.ci = seq_len(nrow(.))-1) %>%
  ctx$addNamespace() %>%
  ctx$save()

