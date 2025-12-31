# mixturemodelsr

R interface to the [Mixture-Models](https://github.com/kasakh/Mixture-Models) Python package for fitting mixture models using gradient-based optimization.

## Overview

`mixturemodelsr` provides R wrappers around the Python Mixture-Models library, which implements various mixture model families with gradient-based optimization including Newton-CG. Unlike traditional EM-based approaches, this package uses automatic differentiation for efficient parameter estimation, making it suitable for high-dimensional data.

### Supported Model Families

- **GMM**: Gaussian Mixture Models
  - Standard GMM
  - Constrained GMM (common covariance)
- **Mclust**: MCLUST family of constrained GMMs (14 covariance structures)
- **MFA**: Mixture of Factor Analyzers
- **PGMM**: Parsimonious GMM with constraints
- **TMM**: t-Mixture Models (robust to outliers)

### Key Features

- **Gradient-based optimization**: Newton-CG, Adam, RMSProp, SGD with momentum
- **Automatic differentiation**: Efficient computation of gradients and Hessians
- **Model selection**: AIC, BIC, and likelihood functions
- **Easy installation**: Automatic Python environment management
- **R-friendly API**: Familiar R syntax and data structures

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

## Quick Start

### Basic GMM Example

```r
library(mixturemodelsr)

# Fit a 3-component GMM on iris data
fit <- mm_gmm_fit(iris[, 1:4], k = 3)

# View results
print(fit)

# Get cluster labels
labels <- mm_predict(fit)
table(labels, iris$Species)

# Model selection
mm_bic(fit)
mm_aic(fit)
```

### Mclust Family Example

```r
# Fit Mclust with VVV (most flexible) model
fit_vvv <- mm_mclust_fit(iris[, 1:4], k = 3, model_type = "VVV")

# Fit Mclust with EII (spherical, equal volume) model
fit_eii <- mm_mclust_fit(iris[, 1:4], k = 3, model_type = "EII")

# Compare models
mm_bic(fit_vvv)
mm_bic(fit_eii)
```

### MFA Example

```r
# Mixture of Factor Analyzers with 2 latent factors
fit_mfa <- mm_mfa_fit(iris[, 1:4], k = 3, q = 2)
mm_bic(fit_mfa)
```

### TMM Example (Robust to Outliers)

```r
# t-Mixture Model (robust to outliers)
fit_tmm <- mm_tmm_fit(iris[, 1:4], k = 3)
labels <- mm_predict(fit_tmm)
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

## Mclust Model Types

The Mclust family uses a three-letter naming convention:
- **First letter**: Volume (E=equal, V=variable)
- **Second letter**: Shape (E=equal, V=variable, I=identity)
- **Third letter**: Orientation (E=equal, V=variable, I=identity)

Common model types:
- `"EII"`: Spherical, equal volume
- `"VII"`: Spherical, variable volume  
- `"EEE"`: Ellipsoidal, equal volume/shape/orientation
- `"VVV"`: Ellipsoidal, variable (most flexible)

Full list: EII, VII, EEI, VEI, EVI, VVI, EEE, VEE, EVE, VVE, EEV, VEV, EVV, VVV

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

If you use this package, please cite the original Python library:

```
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
