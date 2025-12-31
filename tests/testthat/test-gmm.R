test_that("mm_gmm_fit returns valid mm_fit object", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  # Simple smoke test with iris data
  set.seed(123)
  x <- iris[, 1:4]
  
  fit <- mm_gmm_fit(x, k = 3, optimizer = "Newton-CG", scale = 0.5)
  
  expect_s3_class(fit, "mm_fit")
  expect_equal(fit$model_name, "GMM")
  expect_equal(fit$k, 3)
  expect_equal(fit$n, nrow(x))
  expect_equal(fit$d, ncol(x))
  expect_equal(fit$optimizer, "Newton-CG")
})

test_that("mm_predict works with GMM", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  fit <- mm_gmm_fit(x, k = 3, optimizer = "Newton-CG", scale = 0.5)
  
  labels <- mm_predict(fit)
  
  expect_type(labels, "integer")
  expect_equal(length(labels), nrow(x))
  expect_true(all(labels >= 1 & labels <= 3))
})

test_that("mm_aic and mm_bic work with GMM", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  fit <- mm_gmm_fit(x, k = 3, optimizer = "Newton-CG", scale = 0.5)
  
  aic_val <- mm_aic(fit)
  bic_val <- mm_bic(fit)
  
  expect_type(aic_val, "double")
  expect_type(bic_val, "double")
  expect_true(is.finite(aic_val))
  expect_true(is.finite(bic_val))
})

test_that("mm_gmm_constrained_fit works", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  fit <- mm_gmm_constrained_fit(x, k = 3)
  
  expect_s3_class(fit, "mm_fit")
  expect_equal(fit$model_name, "GMM_Constrained")
})
