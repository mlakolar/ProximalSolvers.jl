// Task-owned bridge around the unchanged pinned libslope implementation.
#include <slope/slope.h>
#include <chrono>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <new>
#include <limits>

#ifdef COUNT_ALLOCATIONS
static thread_local bool measuring = false;
static thread_local uint64_t allocation_bytes = 0, allocation_calls = 0;
static inline void record(size_t n) { if(measuring) { allocation_bytes += n; ++allocation_calls; } }
extern "C" void* __real_malloc(size_t);
extern "C" void* __real_calloc(size_t,size_t);
extern "C" void* __real_realloc(void*,size_t);
extern "C" void __real_free(void*);
extern "C" void* __wrap_malloc(size_t n) { record(n); return __real_malloc(n); }
extern "C" void* __wrap_calloc(size_t n,size_t s) { record(n*s); return __real_calloc(n,s); }
extern "C" void* __wrap_realloc(void* p,size_t n) { record(n); return __real_realloc(p,n); }
extern "C" void __wrap_free(void* p) { __real_free(p); }
void* operator new(size_t n) { record(n); if(auto p=__real_malloc(n?n:1)) return p; throw std::bad_alloc(); }
void* operator new[](size_t n) { return ::operator new(n); }
void operator delete(void* p) noexcept { __real_free(p); }
void operator delete[](void* p) noexcept { __real_free(p); }
void operator delete(void* p,size_t) noexcept { __real_free(p); }
void operator delete[](void* p,size_t) noexcept { __real_free(p); }
#endif

extern "C" __attribute__((visibility("default"))) uint64_t slope_allocation_probe() {
#ifdef COUNT_ALLOCATIONS
  allocation_bytes=allocation_calls=0; measuring=true;
  volatile void* a=::operator new(101); void* b=__wrap_malloc(103);
  b=__wrap_realloc(b,107); void* c=__wrap_calloc(3,37);
  ::operator delete(const_cast<void*>(a)); __wrap_free(b); __wrap_free(c);
  measuring=false;
  return allocation_bytes;
#else
  return 0;
#endif
}

template<class Matrix>
static int fit(Matrix& x,const double* y,const double* weights,const double* alphas,
               int n,int p,int levels,double tolerance,int maxiter,double seconds,
               double* coefficients,int* passes,int* returned) {
  Eigen::Map<const Eigen::VectorXd> response(y,n);
  Eigen::Map<const Eigen::ArrayXd> lambda(weights,p), alpha(alphas,levels);
  slope::Slope model;
  model.setSolver("hybrid");model.setScreening("strong");model.setLoss("quadratic");
  model.setIntercept(false);model.setCentering("none");model.setScaling("none");
  model.setModifyX(false);model.setTol(tolerance);model.setMaxIterations(maxiter);
  model.setMaxClusters(p+1);model.setDevChangeTol(0.0);model.setDevRatioTol(1.0);
  model.setHybridCdType("permuted");model.setRandomSeed(95);model.setUpdateClusters(true);
  auto start=std::chrono::steady_clock::now();
  auto interrupt=[&](){return std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()>=seconds;};
  auto path=model.path(x,response,alpha,lambda,interrupt);
  *returned=path.size();
  for(int k=0;k<*returned;++k){
    if(std::abs(path(k).getAlpha()-alphas[k])>1e-12*std::max(1.0,std::abs(alphas[k])))
      throw std::runtime_error("changed native alpha grid");
    Eigen::Map<Eigen::VectorXd> out(coefficients+k*p,p);
    out=Eigen::VectorXd(path(k).getCoefs(false));passes[k]=path(k).getPasses();
  }
  return 0;
}
extern "C" __attribute__((visibility("default"))) int slope_matched(
    const double* x,const int* outer,const int* inner,int nonzeros,const double* y,
    const double* weights,const double* alphas,int n,int p,int levels,int sparse,
    double tolerance,int maxiter,double seconds,double* coefficients,int* passes,
    int* returned,uint64_t* bytes,uint64_t* calls,char* error,int capacity) {
  try {
#ifdef COUNT_ALLOCATIONS
    allocation_bytes=allocation_calls=0;measuring=true;
#endif
    int code;
    if(sparse) {
      Eigen::Map<Eigen::SparseMatrix<double>> design(n,p,nonzeros,const_cast<int*>(outer),const_cast<int*>(inner),const_cast<double*>(x));
      code=fit(design,y,weights,alphas,n,p,levels,tolerance,maxiter,seconds,coefficients,passes,returned);
    } else {
      Eigen::Map<Eigen::MatrixXd> design(const_cast<double*>(x),n,p);
      code=fit(design,y,weights,alphas,n,p,levels,tolerance,maxiter,seconds,coefficients,passes,returned);
    }
#ifdef COUNT_ALLOCATIONS
    measuring=false;*bytes=allocation_bytes;*calls=allocation_calls;
#else
    *bytes=0;*calls=0;
#endif
    return code;
  } catch(const std::exception& e) {
#ifdef COUNT_ALLOCATIONS
    measuring=false;
#endif
    std::snprintf(error,capacity,"%s",e.what()); return 1;
  }
}
