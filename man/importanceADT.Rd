% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/importanceADT.R
\name{importanceADT}
\alias{importanceADT}
\title{A function to calculate the importance score of ADT}
\usage{
importanceADT(
  sce,
  altExp_name = "ADT",
  exprs_value = "logcounts",
  method = c("randomForest", "PCA"),
  group = NULL,
  subsample = TRUE,
  times = 10,
  prop = 0.8,
  k_pca = 5,
  remove_first_PC = TRUE,
  ...
)
}
\arguments{
\item{sce}{A singlecellexperiment object}

\item{altExp_name}{A character indicates which expression matrix is used. by default is none (i.e. RNA).}

\item{exprs_value}{A character indicates which expression value in assayNames is used.}

\item{method}{A character indicates the method of ADT importance calculation,
either randomForest or PCA}

\item{group}{A vector indicates the grouping of the data (for random forest)}

\item{subsample}{Whether perform subsampling (for random forest)}

\item{times}{A numeric indicates the times of subsampling is performed (for random forest)}

\item{prop}{A numeric indicates the proportion of cells are subsampled from the whole data (for random forest)}

\item{k_pca}{Number of principal component will be used to calculate the loading scores (for PCA)}

\item{remove_first_PC}{A logical input indicates whether the first component will be removed from calculation (for PCA).}

\item{...}{other arguments to `randomForest()` or `prcomp()` function}
}
\description{
A function to calculate the importance score of ADT
}
\details{
For random forest, the importance scores are based on features importance.
For PCA, it implements the method proposed in Levin et al (based on the loading of features).
}
\references{
Levine, J.H., Simonds, E.F., Bendall, S.C., Davis, K.L., El-ad, D.A., Tadmor, M.D.,
Litvin, O., Fienberg, H.G., Jager, A., Zunder, E.R. and Finck, R., 2015.
Data-driven phenotypic dissection of AML reveals progenitor-like cells that
correlate with prognosis. Cell, 162(1), pp.184-197.
}
