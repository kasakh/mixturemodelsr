#' Fit an MCLUST Family Model
#'
#' Fits a model from the MCLUST family of constrained Gaussian mixture models.
#' MCLUST models specify different parameterizations of the covariance structure.
#'
#' @param x Numeric matrix or data.frame (rows = observations, columns = features)
#' @param k Number of mixture components
#' @param model_type Character string specifying the MCLUST model type. Common types include:
#'   "EII", "VII", "EEI", "VEI", "EVI", "VVI", "EEE", "VEE", "EVE", "VVE", 
#'   "EEV", "VEV", "EVV", "VVV"
#'   If NULL, uses default from Python implementation.
#' @param optimizer Optimizer name: "Newton-CG" (default), "grad_descent", 
#'   "rms_prop", or "adam"
#' @param scale Initialization scale parameter (default 0.5)
#' @param ... Additional arguments passed to Python init_params() or fit() methods
#'
#' @details
#' MCLUST model types follow a three-letter naming convention:
#' - First letter: Volume (E=equal across components, V=variable across components)
#' - Second letter: Shape (E=equal, V=variable, I=spherical/identity)
#' - Third letter: Orientation (E=equal, V=variable, I=axis-aligned/identity)
#' 
#' Common model types:
#' - "EII": Spherical, equal volume
#' - "VII": Spherical, variable volume
#' - "EEE": Ellipsoidal, equal volume, shape, and orientation
#' - "VVV": Ellipsoidal, variable volume, shape, and orientation (most flexible)
#'
#' @return An mm_fit object
#' @export
#'
#' @examples
#' \dontrun{
#' # Fit MCLUST with VVV (most flexible) model
#' fit <- mm_mclust_fit(iris[, 1:4], k = 3, model_type = "VVV")
#' mm_bic(fit)
#' 
#' # Fit MCLUST with spherical, equal volume model
#' fit_eii <- mm_mclust_fit(iris[, 1:4], k = 3, model_type = "EII")
#' mm_bic(fit_eii)
#' 
#' # Compare models
#' labels <- mm_predict(fit)
#' table(labels, iris$Species)
#' }
mm_mclust_fit <- function(x, k, model_type = NULL, optimizer = "Newton-CG", 
                          scale = 0.5, ...) {
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
    model <- mm$Mclust(py_x, model_type = model_type)
  } else {
    model <- mm$Mclust(py_x)
  }
  
  # Initialize parameters
  init_params <- model$init_params(
    num_components = as.integer(k),
    scale = as.numeric(scale)
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
  model_name <- if (!is.null(model_type)) {
    paste0("Mclust_", model_type)
  } else {
    "Mclust"
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
