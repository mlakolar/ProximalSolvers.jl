; Function Attrs: noinline
define float @julia_pass_1896({}* noundef nonnull align 8 dereferenceable(72) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe471 = alloca [3 x {}*], align 16
  %gcframe471.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe471, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe471 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %newstruct74 = alloca { [1 x [1 x i64]], i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe471 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe471, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe471.sub, {}*** %9, align 8
  %10 = bitcast {}* %0 to {}**
  %11 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %12 = icmp slt i64 %2, 1
  br i1 %12, label %L318, label %L17.preheader

L17.preheader:                                    ; preds = %top
  %getfield = load atomic {}*, {}** %10 unordered, align 8
  %13 = bitcast {}* %1 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %13, i64 0, i32 1
  %14 = bitcast {}* %getfield to {}**
  %15 = bitcast {}* %getfield to i8*
  %getfield_addr13 = getelementptr inbounds i8, i8* %15, i64 24
  %16 = bitcast i8* %getfield_addr13 to {}**
  %getfield_addr15 = getelementptr inbounds i8, i8* %15, i64 32
  %17 = bitcast i8* %getfield_addr15 to {}**
  %18 = bitcast {}* %1 to float**
  %19 = bitcast {}* %0 to i8*
  %20 = getelementptr inbounds i8, i8* %19, i64 8
  %aggregate_load_box.sroa.0.0..sroa_idx = bitcast i8* %20 to float*
  %memcpy_refined_dst = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct74, i64 0, i32 0, i64 0, i64 0
  %21 = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct74, i64 0, i32 1
  %22 = load i64, i64* %arraylen_ptr, align 8
  %23 = icmp eq i64 %22, 0
  br i1 %23, label %L318.loopexit, label %L17

L17thread-pre-split:                              ; preds = %L307
  %24 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %22, %L17.preheader ]
  %value_phi9221.lcssa247 = phi i64 [ %value_phi9221.lcssa246, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %arraysize70208.lcssa238 = phi i64 [ %arraysize70208.lcssa237, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %value_phi3 = phi i64 [ %24, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi float [ %value_phi65, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L307, label %L31

L31:                                              ; preds = %L295, %L17
  %value_phi9224 = phi i64 [ %value_phi9221, %L295 ], [ %value_phi9221.lcssa247, %L17 ]
  %arraysize70211 = phi i64 [ %arraysize70208, %L295 ], [ %arraysize70208.lcssa238, %L17 ]
  %value_phi8 = phi float [ %279, %L295 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %280, %L295 ], [ 1, %L17 ]
  %getfield12 = load atomic {}*, {}** %14 unordered, align 8
  %getfield14 = load atomic {}*, {}** %16 unordered, align 8
  %getfield16 = load atomic {}*, {}** %17 unordered, align 8
  %25 = add nsw i64 %value_phi9, -1
  %26 = bitcast {}* %getfield16 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr17 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %26, i64 0, i32 1
  %arraylen18 = load i64, i64* %arraylen_ptr17, align 8
  %inbounds = icmp ult i64 %25, %arraylen18
  br i1 %inbounds, label %idxend, label %oob

L40:                                              ; preds = %idxend
  br i1 %.not156, label %L124, label %L54.lr.ph

L54.lr.ph:                                        ; preds = %L40
  %27 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr = getelementptr inbounds {}*, {}** %27, i64 3
  %28 = bitcast {}** %arraysize_ptr to i64*
  %arraysize = load i64, i64* %28, align 8
  %29 = mul i64 %arraysize, %25
  %30 = bitcast {}* %getfield12 to float**
  %arrayptr27146 = load float*, float** %30, align 8
  %31 = bitcast {}* %getfield14 to float**
  %arrayptr30147 = load float*, float** %31, align 8
  %min.iters.check389 = icmp ult i64 %arraylen116, 8
  br i1 %min.iters.check389, label %scalar.ph388, label %vector.ph390

vector.ph390:                                     ; preds = %L54.lr.ph
  %n.vec392 = and i64 %arraylen116, 9223372036854775800
  %32 = add nsw i64 %n.vec392, -8
  %33 = lshr exact i64 %32, 3
  %34 = add nuw nsw i64 %33, 1
  %xtraiter = and i64 %34, 3
  %35 = icmp ult i64 %32, 24
  br i1 %35, label %middle.block387.unr-lcssa, label %vector.ph390.new

vector.ph390.new:                                 ; preds = %vector.ph390
  %unroll_iter = and i64 %34, 4611686018427387900
  br label %vector.body395

vector.body395:                                   ; preds = %vector.body395, %vector.ph390.new
  %index396 = phi i64 [ 0, %vector.ph390.new ], [ %index.next402.3, %vector.body395 ]
  %vec.phi397 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390.new ], [ %75, %vector.body395 ]
  %vec.phi398 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390.new ], [ %77, %vector.body395 ]
  %vec.phi399 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390.new ], [ %79, %vector.body395 ]
  %niter = phi i64 [ 0, %vector.ph390.new ], [ %niter.next.3, %vector.body395 ]
  %36 = add i64 %29, %index396
  %37 = getelementptr inbounds float, float* %arrayptr27146, i64 %36
  %38 = bitcast float* %37 to <8 x float>*
  %wide.load400 = load <8 x float>, <8 x float>* %38, align 4
  %39 = getelementptr inbounds float, float* %arrayptr30147, i64 %index396
  %40 = bitcast float* %39 to <8 x float>*
  %wide.load401 = load <8 x float>, <8 x float>* %40, align 4
  %41 = fmul contract <8 x float> %wide.load400, %wide.load400
  %42 = fadd reassoc contract <8 x float> %vec.phi397, %41
  %43 = fmul contract <8 x float> %wide.load400, %wide.load401
  %44 = fadd reassoc contract <8 x float> %vec.phi398, %43
  %45 = fmul contract <8 x float> %wide.load401, %wide.load401
  %46 = fadd reassoc contract <8 x float> %vec.phi399, %45
  %index.next402 = or i64 %index396, 8
  %47 = add i64 %29, %index.next402
  %48 = getelementptr inbounds float, float* %arrayptr27146, i64 %47
  %49 = bitcast float* %48 to <8 x float>*
  %wide.load400.1 = load <8 x float>, <8 x float>* %49, align 4
  %50 = getelementptr inbounds float, float* %arrayptr30147, i64 %index.next402
  %51 = bitcast float* %50 to <8 x float>*
  %wide.load401.1 = load <8 x float>, <8 x float>* %51, align 4
  %52 = fmul contract <8 x float> %wide.load400.1, %wide.load400.1
  %53 = fadd reassoc contract <8 x float> %42, %52
  %54 = fmul contract <8 x float> %wide.load400.1, %wide.load401.1
  %55 = fadd reassoc contract <8 x float> %44, %54
  %56 = fmul contract <8 x float> %wide.load401.1, %wide.load401.1
  %57 = fadd reassoc contract <8 x float> %46, %56
  %index.next402.1 = or i64 %index396, 16
  %58 = add i64 %29, %index.next402.1
  %59 = getelementptr inbounds float, float* %arrayptr27146, i64 %58
  %60 = bitcast float* %59 to <8 x float>*
  %wide.load400.2 = load <8 x float>, <8 x float>* %60, align 4
  %61 = getelementptr inbounds float, float* %arrayptr30147, i64 %index.next402.1
  %62 = bitcast float* %61 to <8 x float>*
  %wide.load401.2 = load <8 x float>, <8 x float>* %62, align 4
  %63 = fmul contract <8 x float> %wide.load400.2, %wide.load400.2
  %64 = fadd reassoc contract <8 x float> %53, %63
  %65 = fmul contract <8 x float> %wide.load400.2, %wide.load401.2
  %66 = fadd reassoc contract <8 x float> %55, %65
  %67 = fmul contract <8 x float> %wide.load401.2, %wide.load401.2
  %68 = fadd reassoc contract <8 x float> %57, %67
  %index.next402.2 = or i64 %index396, 24
  %69 = add i64 %29, %index.next402.2
  %70 = getelementptr inbounds float, float* %arrayptr27146, i64 %69
  %71 = bitcast float* %70 to <8 x float>*
  %wide.load400.3 = load <8 x float>, <8 x float>* %71, align 4
  %72 = getelementptr inbounds float, float* %arrayptr30147, i64 %index.next402.2
  %73 = bitcast float* %72 to <8 x float>*
  %wide.load401.3 = load <8 x float>, <8 x float>* %73, align 4
  %74 = fmul contract <8 x float> %wide.load400.3, %wide.load400.3
  %75 = fadd reassoc contract <8 x float> %64, %74
  %76 = fmul contract <8 x float> %wide.load400.3, %wide.load401.3
  %77 = fadd reassoc contract <8 x float> %66, %76
  %78 = fmul contract <8 x float> %wide.load401.3, %wide.load401.3
  %79 = fadd reassoc contract <8 x float> %68, %78
  %index.next402.3 = add nuw i64 %index396, 32
  %niter.next.3 = add i64 %niter, 4
  %niter.ncmp.3 = icmp eq i64 %niter.next.3, %unroll_iter
  br i1 %niter.ncmp.3, label %middle.block387.unr-lcssa, label %vector.body395

middle.block387.unr-lcssa:                        ; preds = %vector.body395, %vector.ph390
  %.lcssa409.ph = phi <8 x float> [ undef, %vector.ph390 ], [ %75, %vector.body395 ]
  %.lcssa408.ph = phi <8 x float> [ undef, %vector.ph390 ], [ %77, %vector.body395 ]
  %.lcssa.ph = phi <8 x float> [ undef, %vector.ph390 ], [ %79, %vector.body395 ]
  %index396.unr = phi i64 [ 0, %vector.ph390 ], [ %index.next402.3, %vector.body395 ]
  %vec.phi397.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390 ], [ %75, %vector.body395 ]
  %vec.phi398.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390 ], [ %77, %vector.body395 ]
  %vec.phi399.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390 ], [ %79, %vector.body395 ]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %middle.block387, label %vector.body395.epil

vector.body395.epil:                              ; preds = %vector.body395.epil, %middle.block387.unr-lcssa
  %index396.epil = phi i64 [ %index.next402.epil, %vector.body395.epil ], [ %index396.unr, %middle.block387.unr-lcssa ]
  %vec.phi397.epil = phi <8 x float> [ %86, %vector.body395.epil ], [ %vec.phi397.unr, %middle.block387.unr-lcssa ]
  %vec.phi398.epil = phi <8 x float> [ %88, %vector.body395.epil ], [ %vec.phi398.unr, %middle.block387.unr-lcssa ]
  %vec.phi399.epil = phi <8 x float> [ %90, %vector.body395.epil ], [ %vec.phi399.unr, %middle.block387.unr-lcssa ]
  %epil.iter = phi i64 [ %epil.iter.next, %vector.body395.epil ], [ 0, %middle.block387.unr-lcssa ]
  %80 = add i64 %29, %index396.epil
  %81 = getelementptr inbounds float, float* %arrayptr27146, i64 %80
  %82 = bitcast float* %81 to <8 x float>*
  %wide.load400.epil = load <8 x float>, <8 x float>* %82, align 4
  %83 = getelementptr inbounds float, float* %arrayptr30147, i64 %index396.epil
  %84 = bitcast float* %83 to <8 x float>*
  %wide.load401.epil = load <8 x float>, <8 x float>* %84, align 4
  %85 = fmul contract <8 x float> %wide.load400.epil, %wide.load400.epil
  %86 = fadd reassoc contract <8 x float> %vec.phi397.epil, %85
  %87 = fmul contract <8 x float> %wide.load400.epil, %wide.load401.epil
  %88 = fadd reassoc contract <8 x float> %vec.phi398.epil, %87
  %89 = fmul contract <8 x float> %wide.load401.epil, %wide.load401.epil
  %90 = fadd reassoc contract <8 x float> %vec.phi399.epil, %89
  %index.next402.epil = add nuw i64 %index396.epil, 8
  %epil.iter.next = add i64 %epil.iter, 1
  %epil.iter.cmp.not = icmp eq i64 %epil.iter.next, %xtraiter
  br i1 %epil.iter.cmp.not, label %middle.block387, label %vector.body395.epil

middle.block387:                                  ; preds = %vector.body395.epil, %middle.block387.unr-lcssa
  %.lcssa409 = phi <8 x float> [ %.lcssa409.ph, %middle.block387.unr-lcssa ], [ %86, %vector.body395.epil ]
  %.lcssa408 = phi <8 x float> [ %.lcssa408.ph, %middle.block387.unr-lcssa ], [ %88, %vector.body395.epil ]
  %.lcssa = phi <8 x float> [ %.lcssa.ph, %middle.block387.unr-lcssa ], [ %90, %vector.body395.epil ]
  %91 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa)
  %92 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa408)
  %93 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa409)
  %cmp.n394 = icmp eq i64 %arraylen116, %n.vec392
  br i1 %cmp.n394, label %L124, label %scalar.ph388

scalar.ph388:                                     ; preds = %middle.block387, %L54.lr.ph
  %bc.resume.val393 = phi i64 [ %n.vec392, %middle.block387 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx403 = phi float [ %93, %middle.block387 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx404 = phi float [ %92, %middle.block387 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx405 = phi float [ %91, %middle.block387 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph388
  %value_phi25195 = phi float [ %bc.merge.rdx403, %scalar.ph388 ], [ %98, %L54 ]
  %value_phi24194 = phi i64 [ %bc.resume.val393, %scalar.ph388 ], [ %103, %L54 ]
  %value_phi23193 = phi float [ %bc.merge.rdx404, %scalar.ph388 ], [ %100, %L54 ]
  %value_phi22192 = phi float [ %bc.merge.rdx405, %scalar.ph388 ], [ %102, %L54 ]
  %94 = add i64 %29, %value_phi24194
  %95 = getelementptr inbounds float, float* %arrayptr27146, i64 %94
  %arrayref28 = load float, float* %95, align 4
  %96 = getelementptr inbounds float, float* %arrayptr30147, i64 %value_phi24194
  %arrayref31 = load float, float* %96, align 4
  %97 = fmul contract float %arrayref28, %arrayref28
  %98 = fadd reassoc contract float %value_phi25195, %97
  %99 = fmul contract float %arrayref28, %arrayref31
  %100 = fadd reassoc contract float %value_phi23193, %99
  %101 = fmul contract float %arrayref31, %arrayref31
  %102 = fadd reassoc contract float %value_phi22192, %101
  %103 = add nuw nsw i64 %value_phi24194, 1
  %exitcond.not = icmp eq i64 %103, %arraylen116
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not156, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %104 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr122 = getelementptr inbounds {}*, {}** %104, i64 3
  %105 = bitcast {}** %arraysize_ptr122 to i64*
  %arraysize123 = load i64, i64* %105, align 8
  %106 = mul i64 %arraysize123, %25
  %107 = bitcast {}* %getfield12 to float**
  %arrayptr126158 = load float*, float** %107, align 8
  %108 = bitcast {}* %getfield14 to float**
  %arrayptr129159 = load float*, float** %108, align 8
  %min.iters.check366 = icmp ult i64 %arraylen116, 16
  br i1 %min.iters.check366, label %scalar.ph365, label %vector.ph367

vector.ph367:                                     ; preds = %L96.lr.ph
  %n.vec369 = and i64 %arraylen116, 9223372036854775792
  %109 = add nsw i64 %n.vec369, -16
  %110 = lshr exact i64 %109, 4
  %111 = add nuw nsw i64 %110, 1
  %xtraiter454 = and i64 %111, 1
  %112 = icmp eq i64 %109, 0
  br i1 %112, label %middle.block364.unr-lcssa, label %vector.ph367.new

vector.ph367.new:                                 ; preds = %vector.ph367
  %unroll_iter461 = and i64 %111, 2305843009213693950
  br label %vector.body372

vector.body372:                                   ; preds = %vector.body372, %vector.ph367.new
  %index373 = phi i64 [ 0, %vector.ph367.new ], [ %index.next382.1, %vector.body372 ]
  %vec.phi374 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367.new ], [ %141, %vector.body372 ]
  %vec.phi375 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367.new ], [ %142, %vector.body372 ]
  %vec.phi376 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367.new ], [ %145, %vector.body372 ]
  %vec.phi377 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367.new ], [ %146, %vector.body372 ]
  %niter462 = phi i64 [ 0, %vector.ph367.new ], [ %niter462.next.1, %vector.body372 ]
  %113 = add i64 %106, %index373
  %114 = getelementptr inbounds float, float* %arrayptr126158, i64 %113
  %115 = bitcast float* %114 to <8 x float>*
  %wide.load378 = load <8 x float>, <8 x float>* %115, align 4
  %116 = getelementptr inbounds float, float* %114, i64 8
  %117 = bitcast float* %116 to <8 x float>*
  %wide.load379 = load <8 x float>, <8 x float>* %117, align 4
  %118 = getelementptr inbounds float, float* %arrayptr129159, i64 %index373
  %119 = bitcast float* %118 to <8 x float>*
  %wide.load380 = load <8 x float>, <8 x float>* %119, align 4
  %120 = getelementptr inbounds float, float* %118, i64 8
  %121 = bitcast float* %120 to <8 x float>*
  %wide.load381 = load <8 x float>, <8 x float>* %121, align 4
  %122 = fmul contract <8 x float> %wide.load378, %wide.load380
  %123 = fmul contract <8 x float> %wide.load379, %wide.load381
  %124 = fadd reassoc contract <8 x float> %vec.phi374, %122
  %125 = fadd reassoc contract <8 x float> %vec.phi375, %123
  %126 = fmul contract <8 x float> %wide.load380, %wide.load380
  %127 = fmul contract <8 x float> %wide.load381, %wide.load381
  %128 = fadd reassoc contract <8 x float> %vec.phi376, %126
  %129 = fadd reassoc contract <8 x float> %vec.phi377, %127
  %index.next382 = or i64 %index373, 16
  %130 = add i64 %106, %index.next382
  %131 = getelementptr inbounds float, float* %arrayptr126158, i64 %130
  %132 = bitcast float* %131 to <8 x float>*
  %wide.load378.1 = load <8 x float>, <8 x float>* %132, align 4
  %133 = getelementptr inbounds float, float* %131, i64 8
  %134 = bitcast float* %133 to <8 x float>*
  %wide.load379.1 = load <8 x float>, <8 x float>* %134, align 4
  %135 = getelementptr inbounds float, float* %arrayptr129159, i64 %index.next382
  %136 = bitcast float* %135 to <8 x float>*
  %wide.load380.1 = load <8 x float>, <8 x float>* %136, align 4
  %137 = getelementptr inbounds float, float* %135, i64 8
  %138 = bitcast float* %137 to <8 x float>*
  %wide.load381.1 = load <8 x float>, <8 x float>* %138, align 4
  %139 = fmul contract <8 x float> %wide.load378.1, %wide.load380.1
  %140 = fmul contract <8 x float> %wide.load379.1, %wide.load381.1
  %141 = fadd reassoc contract <8 x float> %124, %139
  %142 = fadd reassoc contract <8 x float> %125, %140
  %143 = fmul contract <8 x float> %wide.load380.1, %wide.load380.1
  %144 = fmul contract <8 x float> %wide.load381.1, %wide.load381.1
  %145 = fadd reassoc contract <8 x float> %128, %143
  %146 = fadd reassoc contract <8 x float> %129, %144
  %index.next382.1 = add nuw i64 %index373, 32
  %niter462.next.1 = add i64 %niter462, 2
  %niter462.ncmp.1 = icmp eq i64 %niter462.next.1, %unroll_iter461
  br i1 %niter462.ncmp.1, label %middle.block364.unr-lcssa, label %vector.body372

middle.block364.unr-lcssa:                        ; preds = %vector.body372, %vector.ph367
  %.lcssa416.ph = phi <8 x float> [ undef, %vector.ph367 ], [ %141, %vector.body372 ]
  %.lcssa415.ph = phi <8 x float> [ undef, %vector.ph367 ], [ %142, %vector.body372 ]
  %.lcssa414.ph = phi <8 x float> [ undef, %vector.ph367 ], [ %145, %vector.body372 ]
  %.lcssa413.ph = phi <8 x float> [ undef, %vector.ph367 ], [ %146, %vector.body372 ]
  %index373.unr = phi i64 [ 0, %vector.ph367 ], [ %index.next382.1, %vector.body372 ]
  %vec.phi374.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %141, %vector.body372 ]
  %vec.phi375.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %142, %vector.body372 ]
  %vec.phi376.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %145, %vector.body372 ]
  %vec.phi377.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %146, %vector.body372 ]
  %lcmp.mod456.not = icmp eq i64 %xtraiter454, 0
  br i1 %lcmp.mod456.not, label %middle.block364, label %vector.body372.epil.preheader

vector.body372.epil.preheader:                    ; preds = %middle.block364.unr-lcssa
  %147 = add i64 %106, %index373.unr
  %148 = getelementptr inbounds float, float* %arrayptr126158, i64 %147
  %149 = bitcast float* %148 to <8 x float>*
  %wide.load378.epil = load <8 x float>, <8 x float>* %149, align 4
  %150 = getelementptr inbounds float, float* %148, i64 8
  %151 = bitcast float* %150 to <8 x float>*
  %wide.load379.epil = load <8 x float>, <8 x float>* %151, align 4
  %152 = getelementptr inbounds float, float* %arrayptr129159, i64 %index373.unr
  %153 = bitcast float* %152 to <8 x float>*
  %wide.load380.epil = load <8 x float>, <8 x float>* %153, align 4
  %154 = getelementptr inbounds float, float* %152, i64 8
  %155 = bitcast float* %154 to <8 x float>*
  %wide.load381.epil = load <8 x float>, <8 x float>* %155, align 4
  %156 = fmul contract <8 x float> %wide.load378.epil, %wide.load380.epil
  %157 = fmul contract <8 x float> %wide.load379.epil, %wide.load381.epil
  %158 = fadd reassoc contract <8 x float> %vec.phi374.unr, %156
  %159 = fadd reassoc contract <8 x float> %vec.phi375.unr, %157
  %160 = fmul contract <8 x float> %wide.load380.epil, %wide.load380.epil
  %161 = fmul contract <8 x float> %wide.load381.epil, %wide.load381.epil
  %162 = fadd reassoc contract <8 x float> %vec.phi376.unr, %160
  %163 = fadd reassoc contract <8 x float> %vec.phi377.unr, %161
  br label %middle.block364

middle.block364:                                  ; preds = %vector.body372.epil.preheader, %middle.block364.unr-lcssa
  %.lcssa416 = phi <8 x float> [ %.lcssa416.ph, %middle.block364.unr-lcssa ], [ %158, %vector.body372.epil.preheader ]
  %.lcssa415 = phi <8 x float> [ %.lcssa415.ph, %middle.block364.unr-lcssa ], [ %159, %vector.body372.epil.preheader ]
  %.lcssa414 = phi <8 x float> [ %.lcssa414.ph, %middle.block364.unr-lcssa ], [ %162, %vector.body372.epil.preheader ]
  %.lcssa413 = phi <8 x float> [ %.lcssa413.ph, %middle.block364.unr-lcssa ], [ %163, %vector.body372.epil.preheader ]
  %bin.rdx385 = fadd reassoc contract <8 x float> %.lcssa413, %.lcssa414
  %164 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx385)
  %bin.rdx383 = fadd reassoc contract <8 x float> %.lcssa415, %.lcssa416
  %165 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx383)
  %cmp.n371 = icmp eq i64 %arraylen116, %n.vec369
  br i1 %cmp.n371, label %L124, label %scalar.ph365

scalar.ph365:                                     ; preds = %middle.block364, %L96.lr.ph
  %bc.resume.val370 = phi i64 [ %n.vec369, %middle.block364 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx384 = phi float [ %165, %middle.block364 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx386 = phi float [ %164, %middle.block364 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph365
  %value_phi121201 = phi i64 [ %bc.resume.val370, %scalar.ph365 ], [ %173, %L96 ]
  %value_phi120200 = phi float [ %bc.merge.rdx384, %scalar.ph365 ], [ %170, %L96 ]
  %value_phi119199 = phi float [ %bc.merge.rdx386, %scalar.ph365 ], [ %172, %L96 ]
  %166 = add i64 %106, %value_phi121201
  %167 = getelementptr inbounds float, float* %arrayptr126158, i64 %166
  %arrayref127 = load float, float* %167, align 4
  %168 = getelementptr inbounds float, float* %arrayptr129159, i64 %value_phi121201
  %arrayref130 = load float, float* %168, align 4
  %169 = fmul contract float %arrayref127, %arrayref130
  %170 = fadd reassoc contract float %value_phi120200, %169
  %171 = fmul contract float %arrayref130, %arrayref130
  %172 = fadd reassoc contract float %value_phi119199, %171
  %173 = add nuw nsw i64 %value_phi121201, 1
  %exitcond256.not = icmp eq i64 %173, %arraylen116
  br i1 %exitcond256.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block364, %L83, %L54, %middle.block387, %L40
  %value_phi38 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %164, %middle.block364 ], [ %91, %middle.block387 ], [ %172, %L96 ], [ %102, %L54 ]
  %value_phi39 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %165, %middle.block364 ], [ %92, %middle.block387 ], [ %170, %L96 ], [ %100, %L54 ]
  %value_phi40 = phi float [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block364 ], [ %93, %middle.block387 ], [ %arrayref, %L96 ], [ %98, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %25, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L148:                                             ; preds = %idxend46
  %174 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %174, label %L152, label %L150

L150:                                             ; preds = %L148
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 140312453360144 to {}*), float %value_phi40) #2
  unreachable

L152:                                             ; preds = %L148
  %175 = call float @llvm.sqrt.f32(float %value_phi40)
  %176 = fcmp ugt float %175, %aggregate_load_box.sroa.0.0.copyload
  br i1 %176, label %L157, label %L295

L157:                                             ; preds = %L152
  %177 = fdiv float %value_phi39, %value_phi40
  %178 = fmul float %value_phi39, %177
  %179 = fsub float %value_phi38, %178
  %180 = fmul float %value_phi38, 6.250000e-02
  %181 = fcmp uge float %179, %180
  br i1 %181, label %L245, label %L163

L163:                                             ; preds = %L157
  %182 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr69 = getelementptr inbounds {}*, {}** %182, i64 3
  %183 = bitcast {}** %arraysize_ptr69 to i64*
  %arraysize70 = load i64, i64* %183, align 8
  %arraysize_ptr75 = getelementptr inbounds {}*, {}** %182, i64 4
  %184 = bitcast {}** %arraysize_ptr75 to i64*
  %arraysize76 = load i64, i64* %184, align 8
  %.not151 = icmp ult i64 %25, %arraysize76
  br i1 %.not151, label %L184, label %L181

L181:                                             ; preds = %L163
  store i64 %arraysize70, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %21, align 8
  %185 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe471, i64 0, i64 2
  store {}* %getfield53, {}** %185, align 16
  call void @j_throw_boundserror_1901({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct74) #2
  unreachable

L184:                                             ; preds = %L163
  %186 = mul i64 %arraysize70, %25
  %.not152 = icmp eq i64 %arraylen59, 0
  br i1 %.not152, label %L252, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L184
  %187 = bitcast {}* %getfield57 to float**
  %arrayptr92154 = load float*, float** %187, align 8
  %188 = bitcast {}* %getfield53 to float**
  %arrayptr96155 = load float*, float** %188, align 8
  %min.iters.check = icmp ult i64 %arraylen59, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen59, 9223372036854775792
  %broadcast.splatinsert = insertelement <8 x float> poison, float %177, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  %189 = add nsw i64 %n.vec, -16
  %190 = lshr exact i64 %189, 4
  %191 = add nuw nsw i64 %190, 1
  %xtraiter463 = and i64 %191, 1
  %192 = icmp eq i64 %189, 0
  br i1 %192, label %middle.block.unr-lcssa, label %vector.ph.new

vector.ph.new:                                    ; preds = %vector.ph
  %unroll_iter468 = and i64 %191, 2305843009213693950
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph.new
  %index = phi i64 [ 0, %vector.ph.new ], [ %index.next.1, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph.new ], [ %225, %vector.body ]
  %vec.phi358 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph.new ], [ %226, %vector.body ]
  %niter469 = phi i64 [ 0, %vector.ph.new ], [ %niter469.next.1, %vector.body ]
  %193 = getelementptr inbounds float, float* %arrayptr92154, i64 %index
  %194 = bitcast float* %193 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %194, align 4
  %195 = getelementptr inbounds float, float* %193, i64 8
  %196 = bitcast float* %195 to <8 x float>*
  %wide.load359 = load <8 x float>, <8 x float>* %196, align 4
  %197 = add i64 %index, %186
  %198 = getelementptr inbounds float, float* %arrayptr96155, i64 %197
  %199 = bitcast float* %198 to <8 x float>*
  %wide.load360 = load <8 x float>, <8 x float>* %199, align 4
  %200 = getelementptr inbounds float, float* %198, i64 8
  %201 = bitcast float* %200 to <8 x float>*
  %wide.load361 = load <8 x float>, <8 x float>* %201, align 4
  %202 = fmul <8 x float> %broadcast.splat, %wide.load360
  %203 = fmul <8 x float> %broadcast.splat, %wide.load361
  %204 = fsub <8 x float> %wide.load, %202
  %205 = fsub <8 x float> %wide.load359, %203
  %206 = fmul contract <8 x float> %204, %204
  %207 = fmul contract <8 x float> %205, %205
  %208 = fadd reassoc contract <8 x float> %vec.phi, %206
  %209 = fadd reassoc contract <8 x float> %vec.phi358, %207
  %index.next = or i64 %index, 16
  %210 = getelementptr inbounds float, float* %arrayptr92154, i64 %index.next
  %211 = bitcast float* %210 to <8 x float>*
  %wide.load.1 = load <8 x float>, <8 x float>* %211, align 4
  %212 = getelementptr inbounds float, float* %210, i64 8
  %213 = bitcast float* %212 to <8 x float>*
  %wide.load359.1 = load <8 x float>, <8 x float>* %213, align 4
  %214 = add i64 %index.next, %186
  %215 = getelementptr inbounds float, float* %arrayptr96155, i64 %214
  %216 = bitcast float* %215 to <8 x float>*
  %wide.load360.1 = load <8 x float>, <8 x float>* %216, align 4
  %217 = getelementptr inbounds float, float* %215, i64 8
  %218 = bitcast float* %217 to <8 x float>*
  %wide.load361.1 = load <8 x float>, <8 x float>* %218, align 4
  %219 = fmul <8 x float> %broadcast.splat, %wide.load360.1
  %220 = fmul <8 x float> %broadcast.splat, %wide.load361.1
  %221 = fsub <8 x float> %wide.load.1, %219
  %222 = fsub <8 x float> %wide.load359.1, %220
  %223 = fmul contract <8 x float> %221, %221
  %224 = fmul contract <8 x float> %222, %222
  %225 = fadd reassoc contract <8 x float> %208, %223
  %226 = fadd reassoc contract <8 x float> %209, %224
  %index.next.1 = add nuw i64 %index, 32
  %niter469.next.1 = add i64 %niter469, 2
  %niter469.ncmp.1 = icmp eq i64 %niter469.next.1, %unroll_iter468
  br i1 %niter469.ncmp.1, label %middle.block.unr-lcssa, label %vector.body

middle.block.unr-lcssa:                           ; preds = %vector.body, %vector.ph
  %.lcssa420.ph = phi <8 x float> [ undef, %vector.ph ], [ %225, %vector.body ]
  %.lcssa419.ph = phi <8 x float> [ undef, %vector.ph ], [ %226, %vector.body ]
  %index.unr = phi i64 [ 0, %vector.ph ], [ %index.next.1, %vector.body ]
  %vec.phi.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %225, %vector.body ]
  %vec.phi358.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %226, %vector.body ]
  %lcmp.mod465.not = icmp eq i64 %xtraiter463, 0
  br i1 %lcmp.mod465.not, label %middle.block, label %vector.body.epil.preheader

vector.body.epil.preheader:                       ; preds = %middle.block.unr-lcssa
  %227 = getelementptr inbounds float, float* %arrayptr92154, i64 %index.unr
  %228 = bitcast float* %227 to <8 x float>*
  %wide.load.epil = load <8 x float>, <8 x float>* %228, align 4
  %229 = getelementptr inbounds float, float* %227, i64 8
  %230 = bitcast float* %229 to <8 x float>*
  %wide.load359.epil = load <8 x float>, <8 x float>* %230, align 4
  %231 = add i64 %index.unr, %186
  %232 = getelementptr inbounds float, float* %arrayptr96155, i64 %231
  %233 = bitcast float* %232 to <8 x float>*
  %wide.load360.epil = load <8 x float>, <8 x float>* %233, align 4
  %234 = getelementptr inbounds float, float* %232, i64 8
  %235 = bitcast float* %234 to <8 x float>*
  %wide.load361.epil = load <8 x float>, <8 x float>* %235, align 4
  %236 = fmul <8 x float> %broadcast.splat, %wide.load360.epil
  %237 = fmul <8 x float> %broadcast.splat, %wide.load361.epil
  %238 = fsub <8 x float> %wide.load.epil, %236
  %239 = fsub <8 x float> %wide.load359.epil, %237
  %240 = fmul contract <8 x float> %238, %238
  %241 = fmul contract <8 x float> %239, %239
  %242 = fadd reassoc contract <8 x float> %vec.phi.unr, %240
  %243 = fadd reassoc contract <8 x float> %vec.phi358.unr, %241
  br label %middle.block

middle.block:                                     ; preds = %vector.body.epil.preheader, %middle.block.unr-lcssa
  %.lcssa420 = phi <8 x float> [ %.lcssa420.ph, %middle.block.unr-lcssa ], [ %242, %vector.body.epil.preheader ]
  %.lcssa419 = phi <8 x float> [ %.lcssa419.ph, %middle.block.unr-lcssa ], [ %243, %vector.body.epil.preheader ]
  %bin.rdx = fadd reassoc contract <8 x float> %.lcssa419, %.lcssa420
  %244 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n = icmp eq i64 %arraylen59, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi float [ %244, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90206 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %252, %L208 ]
  %value_phi89205 = phi float [ %bc.merge.rdx, %scalar.ph ], [ %251, %L208 ]
  %245 = getelementptr inbounds float, float* %arrayptr92154, i64 %value_phi90206
  %arrayref93 = load float, float* %245, align 4
  %246 = add i64 %value_phi90206, %186
  %247 = getelementptr inbounds float, float* %arrayptr96155, i64 %246
  %arrayref97 = load float, float* %247, align 4
  %248 = fmul float %177, %arrayref97
  %249 = fsub float %arrayref93, %248
  %250 = fmul contract float %249, %249
  %251 = fadd reassoc contract float %value_phi89205, %250
  %252 = add nuw nsw i64 %value_phi90206, 1
  %exitcond257.not = icmp eq i64 %252, %arraylen59
  br i1 %exitcond257.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L157
  %value_phi9223 = phi i64 [ %value_phi9224, %L157 ], [ %value_phi9, %middle.block ], [ %value_phi9, %L208 ]
  %arraysize70210 = phi i64 [ %arraysize70211, %L157 ], [ %arraysize70, %middle.block ], [ %arraysize70, %L208 ]
  %value_phi102 = phi float [ %179, %L157 ], [ %244, %middle.block ], [ %251, %L208 ]
  %253 = fcmp uge float %value_phi102, 0.000000e+00
  br i1 %253, label %L252, label %L250

L250:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 140312453360144 to {}*), float %value_phi102) #2
  unreachable

L252:                                             ; preds = %L245, %L184
  %value_phi9222 = phi i64 [ %value_phi9223, %L245 ], [ %value_phi9, %L184 ]
  %arraysize70209 = phi i64 [ %arraysize70210, %L245 ], [ %arraysize70, %L184 ]
  %value_phi102161 = phi float [ %value_phi102, %L245 ], [ 0.000000e+00, %L184 ]
  %254 = fadd float %177, %arrayref49
  %255 = fdiv float %aggregate_load_box.sroa.0.0.copyload, %175
  %256 = call float @llvm.sqrt.f32(float %value_phi102161)
  %257 = fsub float %175, %aggregate_load_box.sroa.0.0.copyload
  %258 = fcmp uge float %257, 0.000000e+00
  br i1 %258, label %L259, label %L257

L257:                                             ; preds = %L252
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 140312453360144 to {}*), float %257) #2
  unreachable

L259:                                             ; preds = %L252
  %259 = fadd float %175, %aggregate_load_box.sroa.0.0.copyload
  %260 = fcmp uge float %259, 0.000000e+00
  br i1 %260, label %L266, label %L264

L264:                                             ; preds = %L259
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 140312453360144 to {}*), float %259) #2
  unreachable

L266:                                             ; preds = %L259
  %261 = call float @llvm.sqrt.f32(float %257)
  %262 = call float @llvm.sqrt.f32(float %259)
  %263 = fmul float %261, %262
  %264 = fdiv float %256, %263
  %265 = fmul float %255, %264
  %266 = fsub float %254, %265
  %bitcast_coercion = bitcast float %266 to i32
  %267 = icmp sgt i32 %bitcast_coercion, -1
  %268 = select i1 %267, float %266, float 0.000000e+00
  %269 = fcmp ord float %266, 0.000000e+00
  %270 = select i1 %269, float %268, float %266
  %271 = fadd float %254, %265
  %bitcast_coercion111 = bitcast float %271 to i32
  %272 = icmp sgt i32 %bitcast_coercion111, -1
  %273 = fcmp ord float %271, 0.000000e+00
  %274 = and i1 %273, %272
  %275 = select i1 %274, float 0.000000e+00, float %271
  %276 = fadd float %270, %275
  br label %L295

L291:                                             ; preds = %idxend46
  %277 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe471, i64 0, i64 2
  store {}* %getfield, {}** %277, align 16
  %278 = call float @j__sqrt_cold_1902({}* nonnull %0, float %arrayref49, float %value_phi40, i64 signext %value_phi9)
  br label %L295

L295:                                             ; preds = %L291, %L266, %L152
  %value_phi9221 = phi i64 [ %value_phi9222, %L266 ], [ %value_phi9224, %L291 ], [ %value_phi9224, %L152 ]
  %arraysize70208 = phi i64 [ %arraysize70209, %L266 ], [ %arraysize70211, %L291 ], [ %arraysize70211, %L152 ]
  %value_phi61 = phi float [ %276, %L266 ], [ %278, %L291 ], [ 0.000000e+00, %L152 ]
  %279 = fadd float %value_phi8, %value_phi61
  %.not149.not = icmp eq i64 %value_phi9, %arraylen
  %280 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not149.not, label %L307, label %L31

L307:                                             ; preds = %L295, %L17
  %value_phi9221.lcssa246 = phi i64 [ %value_phi9221.lcssa247, %L17 ], [ %value_phi9221, %L295 ]
  %arraysize70208.lcssa237 = phi i64 [ %arraysize70208.lcssa238, %L17 ], [ %arraysize70208, %L295 ]
  %value_phi65 = phi float [ %value_phi4, %L17 ], [ %279, %L295 ]
  %.not150 = icmp eq i64 %value_phi3, %11
  br i1 %.not150, label %L318.loopexit, label %L17thread-pre-split

L318.loopexit:                                    ; preds = %L307, %L17.preheader
  %.us-phi = phi i64 [ undef, %L17.preheader ], [ %value_phi9221.lcssa246, %L307 ]
  %.us-phi254 = phi i64 [ undef, %L17.preheader ], [ %arraysize70208.lcssa237, %L307 ]
  %.us-phi255 = phi float [ 0.000000e+00, %L17.preheader ], [ %value_phi65, %L307 ]
  store i64 %.us-phi254, i64* %memcpy_refined_dst, align 8
  store i64 %.us-phi, i64* %21, align 8
  br label %L318

L318:                                             ; preds = %L318.loopexit, %top
  %value_phi68 = phi float [ 0.000000e+00, %top ], [ %.us-phi255, %L318.loopexit ]
  %281 = load {}*, {}** %6, align 8
  %282 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %281, {}** %282, align 8
  ret float %value_phi68

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %283 = bitcast {}* %getfield16 to float**
  %arrayptr144 = load float*, float** %283, align 8
  %284 = getelementptr inbounds float, float* %arrayptr144, i64 %25
  %arrayref = load float, float* %284, align 4
  %285 = fcmp ord float %arrayref, 0.000000e+00
  %286 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr115 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %286, i64 0, i32 1
  %arraylen116 = load i64, i64* %arraylen_ptr115, align 8
  %.not156 = icmp eq i64 %arraylen116, 0
  br i1 %285, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48148 = load float*, float** %18, align 8
  %287 = getelementptr inbounds float, float* %arrayptr48148, i64 %25
  %arrayref49 = load float, float* %287, align 4
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %288 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %288 unordered, align 8
  %289 = bitcast {}* %getfield51 to i8*
  %getfield_addr56 = getelementptr inbounds i8, i8* %289, i64 24
  %290 = bitcast i8* %getfield_addr56 to {}**
  %getfield57 = load atomic {}*, {}** %290 unordered, align 8
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %291 = bitcast {}* %getfield57 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr58 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %291, i64 0, i32 1
  %arraylen59 = load i64, i64* %arraylen_ptr58, align 8
  %292 = fsub float %value_phi40, %value_phi40
  %293 = fcmp ord float %292, 0.000000e+00
  %294 = sitofp i64 %arraylen59 to float
  %295 = fmul float %294, 0x3980000000000000
  %296 = fcmp ole float %295, %value_phi40
  %297 = and i1 %293, %296
  %298 = fsub float %value_phi38, %value_phi38
  %299 = fcmp ord float %298, 0.000000e+00
  %300 = fcmp ole float %295, %value_phi38
  %301 = and i1 %299, %300
  %302 = and i1 %297, %301
  br i1 %302, label %L148, label %L291
}
