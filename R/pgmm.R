#' Fit a Parsimonious Gaussian Mixture Model (PGMM)
#'
#' Fits a parsimonious GMM with constraints on the covariance structure.
#'
#' @param x Numeric matrix or data.frame (rows = observations, columns = features)
#' @param k Number of mixture components
#' @param model_type Character string specifying the PGMM model type (e.g., "VVV", "EEE", "VEV").
#'   If NULL, uses default from Python implementation.
#' @param q Number of latent factors (NULL for automatic selection)
#' @param optimizer Optimizer name: "Newton-CG" (default), "grad_descent", 
#'   "rms_prop", or "adam"
#' @param scale Initialization scale parameter (default 1.0)
#' @param use_kmeans Logical, whether to use k-means for initializing component means (default TRUE)
#' @param ... Additional arguments passed to Python init_params() or fit() methods
#'
#' @details
#' PGMM model types follow the mclust naming convention:
#' - First letter: Volume (E=equal, V=variable)
#' - Second letter: Shape (E=equal, V=variable)
#' - Third letter: Orientation (E=equal, V=variable, I=identity)
#'
#' @return An mm_fit object
#' @export
#'
#' @examples
#' \dontrun{
#' # Fit PGMM with variable volume, shape, and orientation
#' fit <- mm_pgmm_fit(iris[, 1:4], k = 3, model_type = "VVV")
#' mm_bic(fit)
#' }
mm_pgmm_fit <- function(x, k, model_type = NULL, q = NULL, 
                        optimizer = "Newton-CG", scale = 1.0, use_kmeans = TRUE, ...) {
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
  
  # Import Python module
  mm <- mm_import()
  
  # Convert data to Python
  py_x <- reticulate::r_to_py(x)
  
  # Create model with or without model_type
  if (!is.null(model_type)) {
    model <- mm$PGMM(py_x, model_type = model_type)
  } else {
    model <- mm$PGMM(py_x)
  }
  
  # Initialize parameters
  init_args <- list(
    num_components = as.integer(k),
    scale = as.numeric(scale),
    use_kmeans = use_kmeans
  )
  
  # Add q if provided
  if (!is.null(q)) {
    if (q < 1 || q >= ncol(x)) {
      stop("q must be >= 1 and < ncol(x)", call. = FALSE)
    }
    init_args$q = as.integer(q)
  }
  
  init_params <- do.call(model$init_params, init_args)
  
  # Fit model
  params_store <- model$fit(init_params, optimizer)
  
  # Get final parameters robustly (convert to R list first)
  ps <- reticulate::py_to_r(params_store)
  if (length(ps) == 0) {
    stop("Python fit() returned empty params_store (no iterations)", call. = FALSE)
  }
  final_params <- ps[[length(ps)]]
  
  # Create fit object
  model_name <- if (!is.null(model_type)) {
    paste0("PGMM_", model_type)
  } else {
    "PGMM"
  }
  
  mm_new_fit(
    py_model = model,
    params_store = ps,
    final_params = final_params,
    model_name = model_name,
    k = k,
    call = call,
    n = nrow(x),
    d = ncol(x),
    optimizer = optimizer
  )
}
