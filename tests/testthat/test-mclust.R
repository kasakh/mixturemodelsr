test_that("mm_mclust_fit works with VVV model", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  
  fit <- mm_mclust_fit(x, k = 3, model_type = "VVV")
  
  expect_s3_class(fit, "mm_fit")
  expect_equal(fit$model_name, "Mclust_VVV")
  expect_equal(fit$k, 3)
})

test_that("mm_mclust_fit works with EII model", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  
  fit <- mm_mclust_fit(x, k = 3, model_type = "EII")
  
  expect_s3_class(fit, "mm_fit")
  expect_equal(fit$model_name, "Mclust_EII")
})

test_that("mm_predict works with Mclust", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  fit <- mm_mclust_fit(x, k = 3, model_type = "VVV")
  
  labels <- mm_predict(fit)
  
  expect_type(labels, "integer")
  expect_equal(length(labels), nrow(x))
  expect_true(all(labels >= 1 & labels <= 3))
})

test_that("Model selection works with Mclust", {
  skip_if_not(mm_python_available(), "Python mixture_models not available")
  
  set.seed(123)
  x <- iris[, 1:4]
  fit <- mm_mclust_fit(x, k = 3, model_type = "VVV")
  
  aic_val <- mm_aic(fit)
  bic_val <- mm_bic(fit)
  
  expect_type(aic_val, "double")
  expect_type(bic_val, "double")
  expect_true(is.finite(aic_val))
  expect_true(is.finite(bic_val))
})
