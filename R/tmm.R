#' Fit a t-Mixture Model (TMM)
#'
#' Fits a mixture of multivariate t-distributions to data using gradient-based optimization.
#' T-distributions are more robust to outliers than Gaussian distributions.
#'
#' @param x Numeric matrix or data.frame (rows = observations, columns = features)
#' @param k Number of mixture components
#' @param optimizer Optimizer name: "Newton-CG" (default), "grad_descent", 
#'   "rms_prop", or "adam"
#' @param scale Initialization scale parameter (default 1.0)
#' @param use_kmeans Logical, whether to use k-means for initializing component means (default TRUE)
#' @param ... Additional arguments passed to Python init_params() or fit() methods
#'
#' @details
#' T-mixture models use multivariate t-distributions instead of Gaussians,
#' making them more robust to outliers. Each component has its own degrees of
#' freedom parameter, allowing different tail behaviors.
#'
#' @return An mm_fit object
#' @export
#'
#' @examples
#' \dontrun{
#' # Fit TMM with 3 components (robust to outliers)
#' fit <- mm_tmm_fit(iris[, 1:4], k = 3)
#' mm_bic(fit)
#' 
#' # Get cluster labels
#' labels <- mm_predict(fit)
#' table(labels, iris$Species)
#' }
mm_tmm_fit <- function(x, k, optimizer = "Newton-CG", scale = 1.0, use_kmeans = TRUE, ...) {
  call <- match.call()
  
  # Input validation
  x <- as.matrix(x)
  if (!is.numeric(x)) {
    stop("x must be numeric", call. = FALSE)
  }
  if (nrow(x) < 2) {
    stop("x must have at least 2 rows", call. = FALSE)
  }
  if (k < 1) {
    stop("k must be >= 1", call. = FALSE)
  }
  if (k > nrow(x)) {
    warning("k is greater than number of observations. This may cause issues.")
  }
  
  # Import Python module
  mm <- mm_import()
  
  # Convert data to Python
  py_x <- reticulate::r_to_py(x)
  
  # Create model (TMM in Python)
  model <- mm$TMM(py_x)
  
  # Initialize parameters
  init_params <- model$init_params(
    num_components = as.integer(k),
    scale = as.numeric(scale),
    use_kmeans = use_kmeans
  )
  
  # Fit model
  params_store <- model$fit(init_params, optimizer)
  
  # Get final parameters robustly (convert to R list first)
  ps <- reticulate::py_to_r(params_store)
  if (length(ps) == 0) {
    stop("Python fit() returned empty params_store (no iterations)", call. = FALSE)
  }
  final_params <- ps[[length(ps)]]
  
  # Create fit object
  mm_new_fit(
    py_model = model,
    params_store = ps,
    final_params = final_params,
    model_name = "TMM",
    k = k,
    call = call,
    n = nrow(x),
    d = ncol(x),
    optimizer = optimizer
  )
}
