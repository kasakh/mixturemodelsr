#' Create a new mm_fit object
#' @keywords internal
mm_new_fit <- function(py_model, params_store, final_params, model_name, k, 
                       call, n, d, optimizer, converged = NULL) {
  structure(
    list(
      py_model = py_model,
      params_store = params_store,
      params = final_params,
      model_name = model_name,
      k = k,
      call = call,
      n = n,
      d = d,
      optimizer = optimizer,
      converged = if (is.null(converged)) NA else converged
    ),
    class = "mm_fit"
  )
}

#' Print method for mm_fit objects
#' @param x An mm_fit object
#' @param ... Additional arguments (ignored)
#' @export
print.mm_fit <- function(x, ...) {
  cat("<mm_fit object>\n\n")
  cat("Model family:", x$model_name, "\n")
  cat("Components (k):", x$k, "\n")
  cat("Sample size (n):", x$n, "\n")
  cat("Dimensions (d):", x$d, "\n")
  cat("Optimizer:", x$optimizer, "\n")
  if (!is.na(x$converged)) {
    cat("Converged:", x$converged, "\n")
  }
  cat("\nCall:\n")
  print(x$call)
  cat("\nUse mm_predict(), mm_aic(), mm_bic() for post-hoc analysis.\n")
  invisible(x)
}

#' Predict cluster labels
#'
#' Predicts cluster membership labels for observations using a fitted mixture model.
#'
#' @param fit An mm_fit object returned by mm_*_fit functions
#' @param newx Optional matrix or data.frame of new observations. If NULL, 
#'   predictions are made on the training data.
#'
#' @return Integer vector of cluster labels (0-indexed from Python, converted to 1-indexed for R)
#' @export
#'
#' @examples
#' \dontrun{
#' fit <- mm_gmm_fit(iris[,1:4], k = 3)
#' labels <- mm_predict(fit)
#' table(labels, iris$Species)
#' }
mm_predict <- function(fit, newx = NULL) {
  if (!inherits(fit, "mm_fit")) {
    stop("fit must be an mm_fit object", call. = FALSE)
  }
  
  if (is.null(newx)) {
    # Try to get training data from Python model
    newx <- tryCatch({
      reticulate::py_to_r(fit$py_model$data)
    }, error = function(e) {
      stop("Cannot retrieve training data. Please provide newx explicitly.", call. = FALSE)
    })
  }
  
  newx <- as.matrix(newx)
  if (!is.numeric(newx)) {
    stop("newx must be numeric", call. = FALSE)
  }
  
  py_newx <- reticulate::r_to_py(newx)
  labels <- fit$py_model$labels(py_newx, fit$params)
  
  # Convert from Python to R and add 1 (Python is 0-indexed, R is 1-indexed)
  as.integer(reticulate::py_to_r(labels)) + 1L
}

#' Compute AIC for fitted model
#'
#' @param fit An mm_fit object
#' @return Numeric AIC value
#' @export
#'
#' @examples
#' \dontrun{
#' fit <- mm_gmm_fit(iris[,1:4], k = 3)
#' mm_aic(fit)
#' }
mm_aic <- function(fit) {
  if (!inherits(fit, "mm_fit")) {
    stop("fit must be an mm_fit object", call. = FALSE)
  }
  as.numeric(reticulate::py_to_r(fit$py_model$aic(fit$params)))
}

#' Compute BIC for fitted model
#'
#' @param fit An mm_fit object
#' @return Numeric BIC value
#' @export
#'
#' @examples
#' \dontrun{
#' fit <- mm_gmm_fit(iris[,1:4], k = 3)
#' mm_bic(fit)
#' }
mm_bic <- function(fit) {
  if (!inherits(fit, "mm_fit")) {
    stop("fit must be an mm_fit object", call. = FALSE)
  }
  as.numeric(reticulate::py_to_r(fit$py_model$bic(fit$params)))
}

#' Compute log-likelihood for fitted model
#'
#' @param fit An mm_fit object
#' @return Numeric log-likelihood value
#' @export
#'
#' @examples
#' \dontrun{
#' fit <- mm_gmm_fit(iris[,1:4], k = 3)
#' mm_likelihood(fit)
#' }
mm_likelihood <- function(fit) {
  if (!inherits(fit, "mm_fit")) {
    stop("fit must be an mm_fit object", call. = FALSE)
  }
  as.numeric(reticulate::py_to_r(fit$py_model$likelihood(fit$params)))
}

#' Get parameter values from fit object
#'
#' Extracts the parameter values from a fitted mixture model.
#'
#' @param fit An mm_fit object
#' @param convert Logical, whether to convert Python objects to R (default TRUE)
#'
#' @return Parameter object (structure depends on model family)
#' @export
#'
#' @examples
#' \dontrun{
#' fit <- mm_gmm_fit(iris[,1:4], k = 3)
#' params <- mm_params(fit)
#' }
mm_params <- function(fit, convert = TRUE) {
  if (!inherits(fit, "mm_fit")) {
    stop("fit must be an mm_fit object", call. = FALSE)
  }
  
  if (convert) {
    reticulate::py_to_r(fit$params)
  } else {
    fit$params
  }
}
