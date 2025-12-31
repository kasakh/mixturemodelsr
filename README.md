# mixturemodelsr

R interface to the [Mixture-Models](https://github.com/kasakh/Mixture-Models) Python package for fitting mixture models using gradient-based optimization.

## Overview

**`mixturemodelsr` is the first R package enabling mixture models for high-dimensional data** through gradient-based optimization with Automatic Differentiation (AD). It provides R wrappers around the Python Mixture-Models library, implementing various mixture model families with advanced optimizers including second-order Newton-CG.

### Supported Model Families

- **GMM**: Gaussian Mixture Models
  - Standard GMM
  - Constrained GMM (common covariance)
- **Mclust**: MCLUST family of constrained GMMs (14 covariance structures)
- **MFA**: Mixture of Factor Analyzers
- **PGMM**: Parsimonious GMM with constraints
- **TMM**: t-Mixture Models (robust to outliers)

### Key Features

- **First R package for high-dimensional mixture models**: Overcomes EM limitations using Automatic Differentiation (AD)
- **Gradient-based optimization**: Newton-CG, Adam, RMSProp, SGD with momentum
- **No stringent constraints needed**: Suitable for settings where parameters ≥ sample size
- **Automatic Differentiation (AD)**: Efficient automatic computation of gradients and Hessians
- **Second-order optimization**: Newton-CG unavailable in traditional EM packages
- **Model selection**: AIC, BIC, and likelihood functions
- **Easy installation**: Automatic Python environment management
- **R-friendly API**: Familiar R syntax and data structures

## Why mixturemodelsr?

### High-Dimensional Data Support

Traditional EM-based R packages (mclust, flexmix) struggle with high-dimensional data where the number of free parameters approaches or exceeds the sample size. **mixturemodelsr overcomes these limitations** through:

1. **Automatic Differentiation (AD)**: Uses AD tools to automatically compute gradients and Hessians, enabling gradient-based optimization without manual derivations

2. **No rank deficiency issues**: Unlike EM (where covariance estimates become rank-deficient in high dimensions), gradient-based approaches with proper reparametrization avoid this problem

3. **Minimal constraints**: Fit flexible models without stringent pre-determined constraints on means or covariances, allowing data-driven discovery of cluster structure

4. **Second-order optimization**: Newton-CG provides faster convergence than EM's first-order updates

### Comparison with EM-Based Packages

| Feature | mixturemodelsr | mclust/flexmix (EM) |
|---------|----------------|---------------------|
| **High-dimensional data** | ✅ Yes (p ≥ n supported) | ❌ No (requires constraints) |
| **Optimization** | Gradient-based + Newton-CG | EM (first-order only) |
| **Automatic Differentiation** | ✅ Yes (AD via autograd) | ❌ No (hard-coded updates) |
| **Flexible models** | ✅ Minimal constraints needed | ⚠️ Stringent constraints required for p ≥ n |
| **Convergence** | Fast (second-order) | Slower (first-order) |
| **Extensibility** | Easy (AD handles new models) | Difficult (manual derivations) |

### When to Use mixturemodelsr

- **High-dimensional data**: When p (features) approaches or exceeds n (samples)
- **Flexible modeling**: When you want data-driven cluster discovery without hard constraints
- **Fast convergence**: When second-order optimization matters
- **Research**: When experimenting with new mixture model variants

### When Traditional EM Packages Are Fine

- **Low-dimensional data**: When p << n and simple models suffice
- **Established workflows**: When existing EM-based code works well
- **R-only environments**: When Python dependencies are not acceptable

## Installation

### From GitHub (Development Version)

```r
# Install pak if needed
install.packages("pak")

# Install mixturemodelsr
pak::pak("kasakh/mixturemodelsr")
```

### From r-universe

```r
# Enable repository
options(repos = c(
  kasakh = "https://kasakh.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))

# Install package
install.packages("mixturemodelsr")
```

## Setup

After installation, set up the Python dependencies (first time only):

```r
library(mixturemodelsr)
mm_setup()
```

This will:
1. Create a dedicated conda environment
2. Install Mixture-Models Python package (v0.0.8)
3. Install all required dependencies (numpy, scipy, autograd, etc.)

### Alternative Setup Options

**Use your own Python environment:**
```r
# Set path to your Python
Sys.setenv(MIXTUREMODELSR_PYTHON = "/path/to/python")

# Then manually install:
# pip install Mixture-Models==0.0.8
```

**Custom environment name:**
```r
Sys.setenv(MIXTUREMODELSR_ENVNAME = "my_custom_env")
mm_setup()
```

> **Note:** `mixturemodelsr` uses Python 3.10 and specific package versions internally
> for compatibility with the Mixture-Models library. The `mm_setup()` function handles
> this automatically for R users.

## Quick Start

### Basic GMM Example with ARI

```r
# Install dependencies (once)
install.packages("mclust")  # for ARI calculation

library(mixturemodelsr)
library(mclust)

# One-time Python setup (installs Python 3.10 + dependencies)
mm_setup(force = FALSE)

# Fit a 3-component Gaussian Mixture Model
fit <- mm_gmm_fit(iris[, 1:4], k = 3)

# Predicted cluster labels
labels <- mm_predict(fit)

# Adjusted Rand Index (ARI)
ari <- adjustedRandIndex(labels, iris$Species)
cat("Adjusted Rand Index:", ari, "\n")

# Information criteria
cat("BIC:", mm_bic(fit), "\n")
cat("AIC:", mm_aic(fit), "\n")

# Confusion table
table(Predicted = labels, True = iris$Species)
```

### Model Evaluation Workflow (Recommended)

```r
library(mixturemodelsr)
library(mclust)

# Ensure Python environment is ready
mm_setup()

# Fit model with k-means initialization (default)
fit <- mm_gmm_fit(
  x = iris[, 1:4],
  k = 3,
  optimizer = "Newton-CG",
  use_kmeans = TRUE  # default, provides better initialization
)

# Inspect fitted object
print(fit)

# Extract cluster assignments
labels <- mm_predict(fit)

# Compare against true labels using ARI
ari <- adjustedRandIndex(labels, iris$Species)
cat(sprintf("Adjusted Rand Index (ARI): %.3f\n", ari))

# Model selection metrics
bic <- mm_bic(fit)
aic <- mm_aic(fit)
cat("BIC:", bic, "\n")
cat("AIC:", aic, "\n")

# Confusion matrix
conf_mat <- table(
  Predicted = labels,
  True = iris$Species
)
print(conf_mat)
```

### Mclust Family Example

```r
library(mixturemodelsr)
library(mclust)

mm_setup()

# Fit Mclust with VVV (most flexible) covariance structure
fit_vvv <- mm_mclust_fit(iris[, 1:4], k = 3, model_type = "VVV")

# Fit Mclust with EII (spherical, equal volume) structure
fit_eii <- mm_mclust_fit(iris[, 1:4], k = 3, model_type = "EII")

# Compare models
cat("VVV BIC:", mm_bic(fit_vvv), "\n")
cat("EII BIC:", mm_bic(fit_eii), "\n")

# Best model
best_fit <- if(mm_bic(fit_vvv) < mm_bic(fit_eii)) fit_vvv else fit_eii
labels <- mm_predict(best_fit)
ari <- adjustedRandIndex(labels, iris$Species)
cat("ARI:", ari, "\n")
```

### MFA Example (Mixture of Factor Analyzers)

```r
library(mixturemodelsr)
library(mclust)

mm_setup()

# Fit MFA with 3 components and 2 latent factors
fit_mfa <- mm_mfa_fit(iris[, 1:4], k = 3, q = 2)

# Evaluate
labels <- mm_predict(fit_mfa)
ari <- adjustedRandIndex(labels, iris$Species)
cat("MFA ARI:", ari, "\n")
cat("MFA BIC:", mm_bic(fit_mfa), "\n")
```

### PGMM Example (Parsimonious GMM)

```r
library(mixturemodelsr)
library(mclust)

mm_setup()

# Fit PGMM with VVV model type
fit_pgmm <- mm_pgmm_fit(iris[, 1:4], k = 3, model_type = "VVV")

labels <- mm_predict(fit_pgmm)
ari <- adjustedRandIndex(labels, iris$Species)
cat("PGMM ARI:", ari, "\n")
```

### TMM Example (Robust to Outliers)

```r
library(mixturemodelsr)
library(mclust)

mm_setup()

# t-Mixture Model (robust to outliers)
fit_tmm <- mm_tmm_fit(iris[, 1:4], k = 3)

labels <- mm_predict(fit_tmm)
ari <- adjustedRandIndex(labels, iris$Species)
cat("TMM ARI:", ari, "\n")
```

### GMM_Constrained Example

```r
library(mixturemodelsr)
library(mclust)

mm_setup()

# Constrained GMM (common covariance matrix)
fit_const <- mm_gmm_constrained_fit(iris[, 1:4], k = 3)

labels <- mm_predict(fit_const)
ari <- adjustedRandIndex(labels, iris$Species)
cat("Constrained GMM ARI:", ari, "\n")
```

## Optimizers

All model functions support different optimizers:

```r
# Newton-CG (default, usually fastest)
fit1 <- mm_gmm_fit(x, k = 3, optimizer = "Newton-CG")

# Adam
fit2 <- mm_gmm_fit(x, k = 3, optimizer = "adam")

# Gradient Descent with momentum
fit3 <- mm_gmm_fit(x, k = 3, optimizer = "grad_descent")

# RMSProp
fit4 <- mm_gmm_fit(x, k = 3, optimizer = "rms_prop")
```

## Model Type Options

### Mclust Family (14 Covariance Structures)

The Mclust family uses a three-letter naming convention:
- **First letter**: Volume (E=equal, V=variable)
- **Second letter**: Shape (E=equal, V=variable, I=identity)
- **Third letter**: Orientation (E=equal, V=variable, I=identity)

**Default**: `"VVV"` (most flexible)

**All 14 model types**:
- Spherical: `"EII"`, `"VII"` 
- Diagonal: `"EEI"`, `"VEI"`, `"EVI"`, `"VVI"`
- Ellipsoidal: `"EEE"`, `"VEE"`, `"EVE"`, `"VVE"`, `"EEV"`, `"VEV"`, `"EVV"`, `"VVV"`

**Usage**:
```r
# Default (VVV)
fit_default <- mm_mclust_fit(iris[,1:4], k=3)

# Specify model type
fit_eii <- mm_mclust_fit(iris[,1:4], k=3, model_type="EII")
fit_eee <- mm_mclust_fit(iris[,1:4], k=3, model_type="EEE")
```

### PGMM (Parsimonious GMM - 8 Constraint Types)

PGMM uses a three-letter constraint notation:
- **C**: Common (equal across components)
- **U**: Unique (variable across components)
- **Position 1**: Volume, **Position 2**: Shape, **Position 3**: Orientation

**Default**: `"CCC"` (most constrained)

**All 8 constraint types**:
- `"CCC"` - Common volume, shape, orientation (default)
- `"CCU"` - Common volume & shape, Unique orientation
- `"CUC"` - Common volume & orientation, Unique shape
- `"CUU"` - Common volume, Unique shape & orientation
- `"UCC"` - Unique volume, Common shape & orientation
- `"UCU"` - Unique volume & orientation, Common shape
- `"UUC"` - Unique volume & shape, Common orientation
- `"UUU"` - Unique volume, shape, orientation (most flexible)

**Usage**:
```r
# Default (CCC)
fit_default <- mm_pgmm_fit(iris[,1:4], k=3, q=2)

# Specify constraint type
fit_uuu <- mm_pgmm_fit(iris[,1:4], k=3, model_type="UUU", q=2)
fit_ccu <- mm_pgmm_fit(iris[,1:4], k=3, model_type="CCU", q=2)
```

**Note**: PGMM requires the `q` parameter (number of latent factors).

### MFA (Mixture of Factor Analyzers)

MFA has **no model types** - it's an unconstrained mixture model. Each component has its own factor loading matrix.

**Usage**:
```r
# Only parameters are k (components) and q (latent factors)
fit <- mm_mfa_fit(iris[,1:4], k=3, q=2)
```

### Model Selection Strategy

```r
# Compare different model types
models <- list(
  mclust_vvv = mm_mclust_fit(iris[,1:4], k=3, model_type="VVV"),
  mclust_eee = mm_mclust_fit(iris[,1:4], k=3, model_type="EEE"),
  pgmm_uuu = mm_pgmm_fit(iris[,1:4], k=3, model_type="UUU", q=2),
  pgmm_ccc = mm_pgmm_fit(iris[,1:4], k=3, model_type="CCC", q=2)
)

# Select best by BIC
bics <- sapply(models, mm_bic)
best_model <- models[[which.min(bics)]]
```

## Available Functions

### Model Fitting
- `mm_gmm_fit()` - Gaussian Mixture Model
- `mm_gmm_constrained_fit()` - GMM with common covariance
- `mm_mclust_fit()` - MCLUST family models
- `mm_mfa_fit()` - Mixture of Factor Analyzers
- `mm_pgmm_fit()` - Parsimonious GMM
- `mm_tmm_fit()` - t-Mixture Model

### Inference
- `mm_predict()` - Predict cluster labels
- `mm_aic()` - Akaike Information Criterion
- `mm_bic()` - Bayesian Information Criterion
- `mm_likelihood()` - Log-likelihood
- `mm_params()` - Extract parameter values

### Setup & Diagnostics
- `mm_setup()` - One-time setup of Python dependencies
- `mm_install()` - Install Python packages (advanced)
- `mm_py_info()` - Diagnostic information
- `mm_python_available()` - Check if Python packages available

## Troubleshooting

### Check Installation Status

```r
mm_py_info()
```

This provides detailed diagnostic information including:
- Python configuration
- Environment variables
- Package versions
- Installation status

### Common Issues

**"Python module 'mixture_models' is not available"**
```r
# Solution: Run setup
mm_setup()
```

**Environment already exists**
```r
# Solution: Force reinstall
mm_setup(force = TRUE)
```

**Custom Python environment**
```r
# Set your Python path
Sys.setenv(MIXTUREMODELSR_PYTHON = "/path/to/python")
# Then manually: pip install Mixture-Models==0.0.8
```

## Citation

If you use this package, please cite the Python library papers:

```
@article{kasa2024mixture,
  title={Mixture-Models: a one-stop Python Library for Model-based Clustering using various Mixture Models},
  author={Kasa, Siva Rajesh and Yijie, Hu and Kasa, Santhosh Kumar and Rajan, Vaibhav},
  journal={arXiv preprint arXiv:2402.10229},
  year={2024}
}

@article{kasa2020model,
  title={Model-based Clustering using Automatic Differentiation: Confronting Misspecification and High-Dimensional Data},
  author={Kasa, Siva Rajesh and Rajan, Vaibhav},
  journal={arXiv preprint arXiv:2007.12786},
  year={2020}
}
```

## License

MIT License. See LICENSE file for details.

## Links

- Python Library: https://github.com/kasakh/Mixture-Models
- Python Documentation: https://github.com/kasakh/Mixture-Models/tree/master/Mixture_Models/Examples
- Report Issues: https://github.com/kasakh/Mixture-Models/issues

## Related Packages

- **mclust**: Traditional EM-based mixture modeling in R
- **flexmix**: Flexible mixture modeling
- **mixtools**: Tools for mixture model analysis

The key difference: `mixturemodelsr` uses gradient-based optimization with automatic differentiation, making it more suitable for high-dimensional data and providing access to advanced optimizers like Newton-CG.
