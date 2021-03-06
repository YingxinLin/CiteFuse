#' A function to perform spectral clustering
#'
#'
#' @param affinity An affinity matrix
#' @param K number of clusters
#' @param type type
#' @param fast fast
#' @param maxdim maxdim
#' @param delta delta
#' @param t t
#' @param neigen neigen
#'
#' @importFrom igraph arpack
#' @importFrom methods as
#' @export

spectralClustering <- function(affinity, K = 20, type = 4,
                               fast = T,
                               maxdim = 50, delta = 1e-5,
                               t = 0, neigen = NULL)
{

  # if(kernel) {
  #   eps.val <- diffusionMap::epsilonCompute(1-affinity, 0.01)
  #   L <- exp(-(1-affinity)^2/(eps.val))
  #   d <- rowSums(L)
  #   D <- diag(d)
  #   d[d == 0] <- .Machine$double.eps
  # } else {
  #
  # }


  d <- rowSums(affinity)
  d[d == 0] <- .Machine$double.eps
  D <- diag(d)
  L <- affinity

  # add kernel???



  neff <- K + 1

  if (type == 1) {
    NL <- L
  }
  else if (type == 2) {
    Di <- diag(1/d)
    NL <- Di %*% L
  }
  else if (type == 3) {
    Di <- diag(1/sqrt(d))
    NL <- Di %*% L %*% Di

  } else if (type == 4) {
    v <- sqrt(d)
    NL <- L/(v %*% t(v))
  }

  if (!fast) {
    eig <- eigen(NL)
  }else {
    f = function(x, A = NULL){ # matrix multiplication for ARPACK
      as.matrix(A %*% x)
    }

    n <- nrow(affinity)

    NL <- ifelse(NL > delta, NL, 0)
    NL <- methods::as(NL, "dgCMatrix")


    eig <- igraph::arpack(f, extra = NL, sym = TRUE,
                          options = list(which = 'LA', nev = neff, n = n, ncv = max(min(c(n,4*neff)))))

  }

  psi = eig$vectors / (eig$vectors[,1] %*% matrix(1, 1, neff))#right ev
  eigenvals <- eig$values

  cat('Computing Spectral Clustering \n')

  res <- sort(abs(eigenvals), index.return = TRUE, decreasing = T)
  U <- eig$vectors[, res$ix[1:K]]
  normalize <- function(x) x/sqrt(sum(x^2))

  if (type == 3 | type == 4) {
    U <- t(apply(U, 1, normalize))
  }
  # This part is equal to performing kmeans
  # labels <- kmeans(U, centers = K, nstart = 1000)$cluster
  eigDiscrete <- .discretisation(U)
  eigDiscrete <- eigDiscrete$discrete
  labels <- apply(eigDiscrete, 1, which.max)

  cat('Computing Diffusion Coordinates\n')
  if (t <= 0) {# use multi-scale geometry
    lambda = eigenvals[-1]/(1 - eigenvals[-1])
    lambda = rep(1,n) %*% t(lambda)
    if (is.null(neigen)) {#use no. of dimensions corresponding to 95% dropoff
      lam = lambda[1,]/lambda[1,1]
      # neigen = min(which(lam < .05)) # default number of eigenvalues
      neigen = min(neigen, maxdim, K)
      eigenvals = eigenvals[1:(neigen + 1)]
      cat('Used default value:',neigen,'dimensions\n')
    }
    X = psi[,2:(neigen + 1)]*lambda[, 1:neigen] #diffusion coords. X
  }
  else{# use fixed scale t
    lambda = eigenvals[-1]^t
    lambda = rep(1, n) %*% t(lambda)

    if (is.null(neigen)) {#use no. of dimensions corresponding to 95% dropoff
      lam = lambda[1, ]/lambda[1, 1]
      neigen = min(which(lam < .05)) # default number of eigenvalues
      neigen = min(neigen, maxdim)
      eigenvals = eigenvals[1:(neigen + 1)]
      cat('Used default value:', neigen, 'dimensions\n')
    }

    X = psi[, 2:(neigen + 1)] * lambda[, 1:neigen] #diffusion coords. X
  }

  return(list(labels = labels,
              eigen_values = eig$values,
              eigen_vectors = eig$vectors,
              X = X))
}




.discretisationEigenVectorData <- function(eigenVector) {

  Y = matrix(0,nrow(eigenVector),ncol(eigenVector))
  maxi <- function(x) {
    i = which(x == max(x))
    return(i[1])
  }
  j = apply(eigenVector,1,maxi)
  Y[cbind(1:nrow(eigenVector),j)] = 1

  return(Y)

}


.discretisation <- function(eigenVectors) {

  normalize <- function(x) x / sqrt(sum(x^2))
  eigenVectors = t(apply(eigenVectors,1,normalize))

  n = nrow(eigenVectors)
  k = ncol(eigenVectors)

  R = matrix(0,k,k)
  R[,1] = t(eigenVectors[round(n/2),])

  mini <- function(x) {
    i = which(x == min(x))
    return(i[1])
  }

  c = matrix(0,n,1)
  for (j in 2:k) {
    c = c + abs(eigenVectors %*% matrix(R[,j - 1], k, 1))
    i = mini(c)
    R[,j] = t(eigenVectors[i,])
  }

  lastObjectiveValue = 0
  for (i in 1:1000) {
    eigenDiscrete = .discretisationEigenVectorData(eigenVectors %*% R)

    svde = svd(t(eigenDiscrete) %*% eigenVectors)
    U = svde[['u']]
    V = svde[['v']]
    S = svde[['d']]

    NcutValue = 2 * (n - sum(S))
    if (abs(NcutValue - lastObjectiveValue) < .Machine$double.eps)
      break

    lastObjectiveValue = NcutValue
    R = V %*% t(U)

  }

  return(list(discrete=eigenDiscrete,continuous =eigenVectors))
}



#' A function to reduce the dimension of the similarity matrix
#'
#'
#' @param sce A singlecellexperiment object
#' @param metadata indicates the meta data name of affinity matrix to virsualise
#' @param method the method of visualisation, which can be UMAP, tSNE and diffusion map
#' @param dimNames indicates the name of the reduced dimension results.
#'
#' @param ... other parameters for tsne(), umap()
#' @importFrom uwot umap
#' @importFrom Rtsne Rtsne
#' @importFrom SingleCellExperiment reducedDim
#' @importFrom S4Vectors metadata
#' @importFrom stats as.dist
#' @export

reducedDimSNF <- function(sce,
                          metadata = "SNF_W",
                          method = "UMAP",
                          dimNames = NULL,
                          ...) {

  method <- match.arg(method, c("UMAP", "tSNE"), several.ok = FALSE)

  if (!metadata %in% names(S4Vectors::metadata(sce))) {
    stop("sce does not contain metadata")
  }

  W <- S4Vectors::metadata(sce)[[metadata]]



  if (is.null(dimNames)) {
    dimNames <- paste(method, metadata, sep = "_")
  }


  if ("UMAP" %in% method) {

    dimred <- uwot::umap(as.dist(0.5 - W), ...)
    colnames(dimred) <- paste("UMAP", seq_len(ncol(dimred)), sep = " ")

    SingleCellExperiment::reducedDim(sce, dimNames) <- dimred
  }

  if ("tSNE" %in% method) {
    dimred <- Rtsne::Rtsne(as.dist(0.5 - W), is_distance = TRUE, ...)$Y
    colnames(dimred) <- paste("tSNE", seq_len(ncol(dimred)), sep = " ")

    SingleCellExperiment::reducedDim(sce, dimNames) <- dimred
  }



  return(sce)


}






#' A function to visualise the reduced dimension
#'
#' @param sce A singlecellexperiment object
#' @param dimNames indicates the name of the reduced dimension results.
#' @param colour_by the method of visualisation, which can be UMAP, tSNE and diffusion map
#' @param shape_by the method of visualisation, which can be UMAP, tSNE and diffusion map
#' @param dim a vector of numeric with length of 2 indicates which component is being plot
#'
#' @importFrom SingleCellExperiment reducedDimNames
#' @importFrom SummarizedExperiment colData
#' @importFrom S4Vectors metadata
#' @import ggplot2
#'
#' @export

visualiseDim <- function(sce,
                         dimNames = NULL,
                         colour_by = NULL,
                         shape_by = NULL,
                         dim = 1:2){


  if (!dimNames %in% SingleCellExperiment::reducedDimNames(sce)) {
    stop("sce does not contain dimNames")
  }


  if (is.null(colour_by)) {

    colour_by <- NULL

  }else if (class(colour_by) == "character" & length(colour_by) == 1) {

    if(! colour_by %in% names(colData(sce))) {

      stop("There is no colData with name colour_by")

    } else {

      colour_by <- as.factor(SummarizedExperiment::colData(sce)[, colour_by])

    }

  } else if (length(colour_by) != ncol(sce)) {

    stop("colour_by needs to be a character or a vector with length equal to the number of cells.")

  } else{

    colour_by <- colour_by

  }


  if (is.null(shape_by)) {

    shape_by <- NULL

  }else if (class(shape_by) == "character" & length(shape_by) == 1) {

    if (!shape_by %in% names(colData(sce))) {

      stop("There is no colData with name shape_by")

    } else {

      shape_by <- as.factor(SummarizedExperiment::colData(sce)[, shape_by])

    }

  } else if (length(shape_by) != ncol(sce)) {

    stop("shape_by needs to be a character or a vector with length equal to the number of cells.")

  } else{

    shape_by <- shape_by

  }


  dimred <- reducedDim(sce, dimNames)

  if (is.null(colnames(dimred))) {
    colnames(dimred) <- paste(dimNames, seq_len(ncol(dimred)), sep = "_")
  }

  dimred <- data.frame(dimred)

  ggplot2::ggplot(dimred, aes(x = dimred[, dim[1]], y = dimred[, dim[2]], col = colour_by, shape = shape_by)) +
    geom_point() +
    scale_color_manual(values = cite_colorPal(length(unique(colour_by)))) +
    scale_shape_manual(values = cite_shapePal(length(unique(shape_by)))) +
    theme_bw() +
    theme(aspect.ratio = 1) +
    xlab(colnames(dimred)[dim[1]]) +
    ylab(colnames(dimred)[dim[2]])





}




.normalize <- function(X) {
  row.sum.mdiag <- rowSums(X) - diag(X)
  row.sum.mdiag[row.sum.mdiag == 0] <- 1
  X <- X/(2 * (row.sum.mdiag))
  diag(X) <- 0.5
  return(X)
}

#' A function to perform igraph clustering
#'
#'
#' @param sce A singlecellexperiment object
#' @param metadata indicates the meta data name of affinity matrix to virsualise
#' @param method A character indicates the method for finding communities from igraph. Default is louvain clustering.
#' @param ... Other inputs for the igraph functions
#'
#' @importFrom S4Vectors metadata
#' @importFrom dbscan sNN
#' @importFrom igraph graph_from_adjacency_matrix cluster_louvain
#' cluster_walktrap cluster_spinglass cluster_optimal
#' cluster_edge_betweenness cluster_fast_greedy cluster_label_prop cluster_leading_eigen
#' @importFrom stats median as.dist
#' @export

igraphClustering <- function(sce,
                             metadata = "SNF_W",
                             method = c("louvain", "walktrap", "spinglass", "optimal",
                                        "leading_eigen", "label_prop", "fast_greedy", "edge_betweenness"),
                             ...) {

  method <- match.arg(method, c("louvain", "walktrap", "spinglass", "optimal",
                                "leading_eigen", "label_prop", "fast_greedy", "edge_betweenness"))

  normalized.mat <- S4Vectors::metadata(sce)[[metadata]]
  diag(normalized.mat) <- stats::median(as.vector(normalized.mat))
  normalized.mat <- .normalize(normalized.mat)
  normalized.mat <- normalized.mat + t(normalized.mat)

  binary.mat <- dbscan::sNN(stats::as.dist(0.5 - normalized.mat), k = 20)

  binary.mat <- sapply(1:nrow(normalized.mat), function(x) {
    tmp <- rep(0, ncol(normalized.mat))
    tmp[binary.mat$id[x,]] <- 1
    tmp
  })

  rownames(binary.mat) <- colnames(binary.mat)
  dim(binary.mat)


  g <- igraph::graph_from_adjacency_matrix(binary.mat, mode = "undirected")

  if (method == "louvain") {
    X <- igraph::cluster_louvain(g, ...)
  }

  if (method == "walktrap") {
    X <- igraph::cluster_walktrap(g, ...)
  }

  if (method == "spinglass") {
    X <- igraph::cluster_spinglass(g, ...)
  }

  if (method == "optimal") {
    X <- igraph::cluster_optimal(g, ...)
  }

  if (method == "leading_eigen") {
    X <- igraph::cluster_leading_eigen(g, ...)
  }

  if (method == "label_prop") {
    X <- igraph::cluster_label_prop(g, ...)
  }

  if (method == "fast_greedy") {
    X <- igraph::cluster_fast_greedy(g, ...)
  }

  if (method == "edge_betweenness") {
    X <- igraph::cluster_edge_betweenness(g, ...)
  }

  clustres <- X$membership

  return(clustres)

}




# plot_igraph <- function(X, n) {
#
#   clusteroutput <- spectralClustering4(X, K = n, kernel = T)
#
#   normalized.mat <- X
#   diag(normalized.mat) <- median(as.vector(X))
#   normalized.mat <- normalize(normalized.mat)
#   normalized.mat <- normalized.mat + t(normalized.mat)
#
#   binary.mat <- dbscan::sNN(as.dist(0.5 - normalized.mat), k=20)
#
#   binary.mat <- sapply(1:nrow(normalized.mat), function(x) {
#     tmp <- rep(0, ncol(normalized.mat))
#     tmp[binary.mat$id[x,]] <- 1
#     tmp
#   })
#
#   rownames(binary.mat) <- colnames(binary.mat)
#   dim(binary.mat)
#
#   library(igraph)
#
#   g <- graph_from_adjacency_matrix(binary.mat, mode = "undirected")
#
#   plot(g, vertex.label=NA,
#        edge.arrow.size=0.000001,
#        layout=layout.fruchterman.reingold,
#        vertex.color = tableau_color_pal("Tableau 10")(nlevels(as.factor(clusteroutput$labels)))[clusteroutput$labels],
#        vertex.size = 4)
#
#   return(X)
#
# }
#
#' A function to perform louvain clustering
#'
#'
#' @param sce A singlecellexperiment object
#' @param colour_by the name of coldata that is used to colour the node
#' @param metadata indicates the meta data name of affinity matrix to virsualise
#'
#' @importFrom S4Vectors metadata
#' @importFrom dbscan sNN
#' @importFrom igraph graph_from_adjacency_matrix
#' @importFrom SummarizedExperiment colData
#' @importFrom graphics plot legend
#' @export

visualiseKNN <- function(sce,
                         colour_by = NULL,
                         metadata = "SNF_W") {



  normalized.mat <- S4Vectors::metadata(sce)[[metadata]]
  diag(normalized.mat) <- stats::median(as.vector(normalized.mat))
  normalized.mat <- .normalize(normalized.mat)
  normalized.mat <- normalized.mat + t(normalized.mat)

  binary.mat <- dbscan::sNN(as.dist(0.5 - normalized.mat), k = 20)

  binary.mat <- sapply(1:nrow(normalized.mat), function(x) {
    tmp <- rep(0, ncol(normalized.mat))
    tmp[binary.mat$id[x,]] <- 1
    tmp
  })

  rownames(binary.mat) <- colnames(binary.mat)
  dim(binary.mat)


  g <- igraph::graph_from_adjacency_matrix(binary.mat, mode = "undirected")

  # cat('no. of clusters')
  # print(nlevels(as.factor(X$membership)))
  #
  if (is.null(colour_by)) {
    colour_by <- as.factor(rep(1, ncol(sce)))
  } else {
    colour_by <- as.factor(SummarizedExperiment::colData(sce)[, colour_by])
  }

  graphics::plot(g, vertex.label = NA,
                 edge.arrow.size = 0.000001,
                 layout = igraph::layout.fruchterman.reingold,
                 vertex.color = cite_colorPal(nlevels(colour_by))[as.numeric(colour_by)],
                 vertex.size = 4)

  graphics::legend('bottomright',
                   legend = levels(colour_by),
                   col = cite_colorPal(nlevels(colour_by)),
                   pch = 16,
                   ncol = ceiling(nlevels(colour_by)/10),
                   cex = 0.5)

}


