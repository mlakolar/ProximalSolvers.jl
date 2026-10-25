// Benchmark-only controls around the installed, pinned libslope static library.
#include <slope/slope.h>
#include <chrono>
#include <cstdio>
#include <exception>

extern "C" __attribute__((visibility("default"))) int slope_control(
    const double* x, const double* y, const double* weights, const double* alphas,
    int n, int p, int levels, int solver, int screening, double tolerance,
    int max_iterations, double limit_seconds, double* coefficients,
    int* passes, int* returned, char* error, int error_capacity)
{
  try {
    // Match the existing Julia binding's mutable Eigen::Map, without copying X.
    Eigen::Map<Eigen::MatrixXd> design(const_cast<double*>(x), n, p);
    Eigen::Map<const Eigen::VectorXd> response(y, n);
    Eigen::Map<const Eigen::ArrayXd> lambda(weights, p);
    Eigen::Map<const Eigen::ArrayXd> alpha(alphas, levels);
    slope::Slope model;
    model.setSolver(solver == 0 ? "pgd" : solver == 1 ? "fista" : "hybrid");
    model.setScreening(screening ? "strong" : "none");
    model.setLoss("quadratic");
    model.setIntercept(false);
    model.setCentering("none");
    model.setScaling("none");
    model.setModifyX(false);
    model.setTol(tolerance);
    model.setMaxIterations(max_iterations);
    model.setMaxClusters(p + 1);
    model.setDevChangeTol(0.0);
    model.setDevRatioTol(1.0);
    model.setHybridCdType("permuted");
    model.setRandomSeed(57);
    model.setUpdateClusters(true);
    const auto start = std::chrono::steady_clock::now();
    auto interrupt = [&]() {
      return std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count() >= limit_seconds;
    };
    const auto fit = model.path(design, response, alpha, lambda, interrupt);
    *returned = static_cast<int>(fit.size());
    for (int k = 0; k < *returned; ++k) {
      if (std::abs(fit(k).getAlpha() - alphas[k]) > 1e-12 * std::max(1.0, std::abs(alphas[k])))
        throw std::runtime_error("native path changed alpha grid");
      Eigen::Map<Eigen::VectorXd> output(coefficients + k * p, p);
      output = Eigen::VectorXd(fit(k).getCoefs(false));
      passes[k] = fit(k).getPasses();
    }
    return 0;
  } catch (const std::exception& e) {
    std::snprintf(error, error_capacity, "%s", e.what());
    return 1;
  }
}
