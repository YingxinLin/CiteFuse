% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/runSNF.R
\name{CiteFuse}
\alias{CiteFuse}
\title{A function to runSNF for CITE seq data}
\usage{
CiteFuse(
  sce,
  altExp_name = "ADT",
  W_list = NULL,
  gene_select = TRUE,
  dist_cal_RNA = "correlation",
  dist_cal_ADT = "propr",
  ADT_subset = NULL,
  K_knn = 20,
  t = 20,
  metadata_names = NULL,
  verbose = TRUE
)
}
\arguments{
\item{sce}{a SingleCellExperiment#' @param return_sce A logical input indicates whether a \code{SingleCellExperiment} 
object will be return}

\item{altExp_name}{expression name of ADT matrix}

\item{W_list}{affinity list, if it is NULL, the function will calculate it.}

\item{gene_select}{whether highly variable genes will be selected for RNA-seq to calcualte simlarity matrix}

\item{dist_cal_RNA}{similarity metrics used for RNA matrix}

\item{dist_cal_ADT}{similarity metrics used for ADT matrix}

\item{ADT_subset}{A vector  indicates the subset that will be used.}

\item{K_knn}{Number of nearest neighbours}

\item{t}{Number of iterations for the diffusion process.}

\item{metadata_names}{A vector indicates the names of metadata returned}

\item{verbose}{whether print out the process}
}
\description{
A function to runSNF for CITE seq data
}
