; Function Attrs: noinline
define float @julia_pass_1896({}* noundef nonnull align 8 dereferenceable(72) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe452 = alloca [3 x {}*], align 16
  %gcframe452.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe452, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe452 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %newstruct74 = alloca { [1 x [1 x i64]], i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe452 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe452, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe452.sub, {}*** %9, align 8
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
  %value_phi8 = phi float [ %158, %L295 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %159, %L295 ], [ 1, %L17 ]
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
  br label %vector.body395

vector.body395:                                   ; preds = %vector.body395, %vector.ph390
  %index396 = phi i64 [ 0, %vector.ph390 ], [ %index.next402, %vector.body395 ]
  %vec.phi397 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390 ], [ %38, %vector.body395 ]
  %vec.phi398 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390 ], [ %40, %vector.body395 ]
  %vec.phi399 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph390 ], [ %42, %vector.body395 ]
  %32 = add i64 %29, %index396
  %33 = getelementptr inbounds float, float* %arrayptr27146, i64 %32
  %34 = bitcast float* %33 to <8 x float>*
  %wide.load400 = load <8 x float>, <8 x float>* %34, align 4
  %35 = getelementptr inbounds float, float* %arrayptr30147, i64 %index396
  %36 = bitcast float* %35 to <8 x float>*
  %wide.load401 = load <8 x float>, <8 x float>* %36, align 4
  %37 = fmul contract <8 x float> %wide.load400, %wide.load400
  %38 = fadd reassoc contract <8 x float> %vec.phi397, %37
  %39 = fmul contract <8 x float> %wide.load400, %wide.load401
  %40 = fadd reassoc contract <8 x float> %vec.phi398, %39
  %41 = fmul contract <8 x float> %wide.load401, %wide.load401
  %42 = fadd reassoc contract <8 x float> %vec.phi399, %41
  %index.next402 = add nuw i64 %index396, 8
  %43 = icmp eq i64 %index.next402, %n.vec392
  br i1 %43, label %middle.block387, label %vector.body395

middle.block387:                                  ; preds = %vector.body395
  %44 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %42)
  %45 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %40)
  %46 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %38)
  %cmp.n394 = icmp eq i64 %arraylen116, %n.vec392
  br i1 %cmp.n394, label %L124, label %scalar.ph388

scalar.ph388:                                     ; preds = %middle.block387, %L54.lr.ph
  %bc.resume.val393 = phi i64 [ %n.vec392, %middle.block387 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx403 = phi float [ %46, %middle.block387 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx404 = phi float [ %45, %middle.block387 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx405 = phi float [ %44, %middle.block387 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph388
  %value_phi25195 = phi float [ %bc.merge.rdx403, %scalar.ph388 ], [ %51, %L54 ]
  %value_phi24194 = phi i64 [ %bc.resume.val393, %scalar.ph388 ], [ %56, %L54 ]
  %value_phi23193 = phi float [ %bc.merge.rdx404, %scalar.ph388 ], [ %53, %L54 ]
  %value_phi22192 = phi float [ %bc.merge.rdx405, %scalar.ph388 ], [ %55, %L54 ]
  %47 = add i64 %29, %value_phi24194
  %48 = getelementptr inbounds float, float* %arrayptr27146, i64 %47
  %arrayref28 = load float, float* %48, align 4
  %49 = getelementptr inbounds float, float* %arrayptr30147, i64 %value_phi24194
  %arrayref31 = load float, float* %49, align 4
  %50 = fmul contract float %arrayref28, %arrayref28
  %51 = fadd reassoc contract float %value_phi25195, %50
  %52 = fmul contract float %arrayref28, %arrayref31
  %53 = fadd reassoc contract float %value_phi23193, %52
  %54 = fmul contract float %arrayref31, %arrayref31
  %55 = fadd reassoc contract float %value_phi22192, %54
  %56 = add nuw nsw i64 %value_phi24194, 1
  %exitcond.not = icmp eq i64 %56, %arraylen116
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not156, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %57 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr122 = getelementptr inbounds {}*, {}** %57, i64 3
  %58 = bitcast {}** %arraysize_ptr122 to i64*
  %arraysize123 = load i64, i64* %58, align 8
  %59 = mul i64 %arraysize123, %25
  %60 = bitcast {}* %getfield12 to float**
  %arrayptr126158 = load float*, float** %60, align 8
  %61 = bitcast {}* %getfield14 to float**
  %arrayptr129159 = load float*, float** %61, align 8
  %min.iters.check366 = icmp ult i64 %arraylen116, 16
  br i1 %min.iters.check366, label %scalar.ph365, label %vector.ph367

vector.ph367:                                     ; preds = %L96.lr.ph
  %n.vec369 = and i64 %arraylen116, 9223372036854775792
  br label %vector.body372

vector.body372:                                   ; preds = %vector.body372, %vector.ph367
  %index373 = phi i64 [ 0, %vector.ph367 ], [ %index.next382, %vector.body372 ]
  %vec.phi374 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %73, %vector.body372 ]
  %vec.phi375 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %74, %vector.body372 ]
  %vec.phi376 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %77, %vector.body372 ]
  %vec.phi377 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph367 ], [ %78, %vector.body372 ]
  %62 = add i64 %59, %index373
  %63 = getelementptr inbounds float, float* %arrayptr126158, i64 %62
  %64 = bitcast float* %63 to <8 x float>*
  %wide.load378 = load <8 x float>, <8 x float>* %64, align 4
  %65 = getelementptr inbounds float, float* %63, i64 8
  %66 = bitcast float* %65 to <8 x float>*
  %wide.load379 = load <8 x float>, <8 x float>* %66, align 4
  %67 = getelementptr inbounds float, float* %arrayptr129159, i64 %index373
  %68 = bitcast float* %67 to <8 x float>*
  %wide.load380 = load <8 x float>, <8 x float>* %68, align 4
  %69 = getelementptr inbounds float, float* %67, i64 8
  %70 = bitcast float* %69 to <8 x float>*
  %wide.load381 = load <8 x float>, <8 x float>* %70, align 4
  %71 = fmul contract <8 x float> %wide.load378, %wide.load380
  %72 = fmul contract <8 x float> %wide.load379, %wide.load381
  %73 = fadd reassoc contract <8 x float> %vec.phi374, %71
  %74 = fadd reassoc contract <8 x float> %vec.phi375, %72
  %75 = fmul contract <8 x float> %wide.load380, %wide.load380
  %76 = fmul contract <8 x float> %wide.load381, %wide.load381
  %77 = fadd reassoc contract <8 x float> %vec.phi376, %75
  %78 = fadd reassoc contract <8 x float> %vec.phi377, %76
  %index.next382 = add nuw i64 %index373, 16
  %79 = icmp eq i64 %index.next382, %n.vec369
  br i1 %79, label %middle.block364, label %vector.body372

middle.block364:                                  ; preds = %vector.body372
  %bin.rdx385 = fadd reassoc contract <8 x float> %78, %77
  %80 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx385)
  %bin.rdx383 = fadd reassoc contract <8 x float> %74, %73
  %81 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx383)
  %cmp.n371 = icmp eq i64 %arraylen116, %n.vec369
  br i1 %cmp.n371, label %L124, label %scalar.ph365

scalar.ph365:                                     ; preds = %middle.block364, %L96.lr.ph
  %bc.resume.val370 = phi i64 [ %n.vec369, %middle.block364 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx384 = phi float [ %81, %middle.block364 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx386 = phi float [ %80, %middle.block364 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph365
  %value_phi121201 = phi i64 [ %bc.resume.val370, %scalar.ph365 ], [ %89, %L96 ]
  %value_phi120200 = phi float [ %bc.merge.rdx384, %scalar.ph365 ], [ %86, %L96 ]
  %value_phi119199 = phi float [ %bc.merge.rdx386, %scalar.ph365 ], [ %88, %L96 ]
  %82 = add i64 %59, %value_phi121201
  %83 = getelementptr inbounds float, float* %arrayptr126158, i64 %82
  %arrayref127 = load float, float* %83, align 4
  %84 = getelementptr inbounds float, float* %arrayptr129159, i64 %value_phi121201
  %arrayref130 = load float, float* %84, align 4
  %85 = fmul contract float %arrayref127, %arrayref130
  %86 = fadd reassoc contract float %value_phi120200, %85
  %87 = fmul contract float %arrayref130, %arrayref130
  %88 = fadd reassoc contract float %value_phi119199, %87
  %89 = add nuw nsw i64 %value_phi121201, 1
  %exitcond256.not = icmp eq i64 %89, %arraylen116
  br i1 %exitcond256.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block364, %L83, %L54, %middle.block387, %L40
  %value_phi38 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %80, %middle.block364 ], [ %44, %middle.block387 ], [ %88, %L96 ], [ %55, %L54 ]
  %value_phi39 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %81, %middle.block364 ], [ %45, %middle.block387 ], [ %86, %L96 ], [ %53, %L54 ]
  %value_phi40 = phi float [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block364 ], [ %46, %middle.block387 ], [ %arrayref, %L96 ], [ %51, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %25, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L148:                                             ; preds = %idxend46
  %90 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %90, label %L152, label %L150

L150:                                             ; preds = %L148
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 136709640595984 to {}*), float %value_phi40) #2
  unreachable

L152:                                             ; preds = %L148
  %91 = call float @llvm.sqrt.f32(float %value_phi40)
  %92 = fcmp ugt float %91, %aggregate_load_box.sroa.0.0.copyload
  br i1 %92, label %L157, label %L295

L157:                                             ; preds = %L152
  %93 = fdiv float %value_phi39, %value_phi40
  %94 = fmul float %value_phi39, %93
  %95 = fsub float %value_phi38, %94
  %96 = fmul float %value_phi38, 6.250000e-02
  %97 = fcmp uge float %95, %96
  br i1 %97, label %L245, label %L163

L163:                                             ; preds = %L157
  %98 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr69 = getelementptr inbounds {}*, {}** %98, i64 3
  %99 = bitcast {}** %arraysize_ptr69 to i64*
  %arraysize70 = load i64, i64* %99, align 8
  %arraysize_ptr75 = getelementptr inbounds {}*, {}** %98, i64 4
  %100 = bitcast {}** %arraysize_ptr75 to i64*
  %arraysize76 = load i64, i64* %100, align 8
  %.not151 = icmp ult i64 %25, %arraysize76
  br i1 %.not151, label %L184, label %L181

L181:                                             ; preds = %L163
  store i64 %arraysize70, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %21, align 8
  %101 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe452, i64 0, i64 2
  store {}* %getfield53, {}** %101, align 16
  call void @j_throw_boundserror_1901({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct74) #2
  unreachable

L184:                                             ; preds = %L163
  %102 = mul i64 %arraysize70, %25
  %.not152 = icmp eq i64 %arraylen59, 0
  br i1 %.not152, label %L252, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L184
  %103 = bitcast {}* %getfield57 to float**
  %arrayptr92154 = load float*, float** %103, align 8
  %104 = bitcast {}* %getfield53 to float**
  %arrayptr96155 = load float*, float** %104, align 8
  %min.iters.check = icmp ult i64 %arraylen59, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen59, 9223372036854775792
  %broadcast.splatinsert = insertelement <8 x float> poison, float %93, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %120, %vector.body ]
  %vec.phi358 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %121, %vector.body ]
  %105 = getelementptr inbounds float, float* %arrayptr92154, i64 %index
  %106 = bitcast float* %105 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %106, align 4
  %107 = getelementptr inbounds float, float* %105, i64 8
  %108 = bitcast float* %107 to <8 x float>*
  %wide.load359 = load <8 x float>, <8 x float>* %108, align 4
  %109 = add i64 %index, %102
  %110 = getelementptr inbounds float, float* %arrayptr96155, i64 %109
  %111 = bitcast float* %110 to <8 x float>*
  %wide.load360 = load <8 x float>, <8 x float>* %111, align 4
  %112 = getelementptr inbounds float, float* %110, i64 8
  %113 = bitcast float* %112 to <8 x float>*
  %wide.load361 = load <8 x float>, <8 x float>* %113, align 4
  %114 = fmul <8 x float> %broadcast.splat, %wide.load360
  %115 = fmul <8 x float> %broadcast.splat, %wide.load361
  %116 = fsub <8 x float> %wide.load, %114
  %117 = fsub <8 x float> %wide.load359, %115
  %118 = fmul contract <8 x float> %116, %116
  %119 = fmul contract <8 x float> %117, %117
  %120 = fadd reassoc contract <8 x float> %vec.phi, %118
  %121 = fadd reassoc contract <8 x float> %vec.phi358, %119
  %index.next = add nuw i64 %index, 16
  %122 = icmp eq i64 %index.next, %n.vec
  br i1 %122, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <8 x float> %121, %120
  %123 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n = icmp eq i64 %arraylen59, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi float [ %123, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90206 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %131, %L208 ]
  %value_phi89205 = phi float [ %bc.merge.rdx, %scalar.ph ], [ %130, %L208 ]
  %124 = getelementptr inbounds float, float* %arrayptr92154, i64 %value_phi90206
  %arrayref93 = load float, float* %124, align 4
  %125 = add i64 %value_phi90206, %102
  %126 = getelementptr inbounds float, float* %arrayptr96155, i64 %125
  %arrayref97 = load float, float* %126, align 4
  %127 = fmul float %93, %arrayref97
  %128 = fsub float %arrayref93, %127
  %129 = fmul contract float %128, %128
  %130 = fadd reassoc contract float %value_phi89205, %129
  %131 = add nuw nsw i64 %value_phi90206, 1
  %exitcond257.not = icmp eq i64 %131, %arraylen59
  br i1 %exitcond257.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L157
  %value_phi9223 = phi i64 [ %value_phi9224, %L157 ], [ %value_phi9, %middle.block ], [ %value_phi9, %L208 ]
  %arraysize70210 = phi i64 [ %arraysize70211, %L157 ], [ %arraysize70, %middle.block ], [ %arraysize70, %L208 ]
  %value_phi102 = phi float [ %95, %L157 ], [ %123, %middle.block ], [ %130, %L208 ]
  %132 = fcmp uge float %value_phi102, 0.000000e+00
  br i1 %132, label %L252, label %L250

L250:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 136709640595984 to {}*), float %value_phi102) #2
  unreachable

L252:                                             ; preds = %L245, %L184
  %value_phi9222 = phi i64 [ %value_phi9223, %L245 ], [ %value_phi9, %L184 ]
  %arraysize70209 = phi i64 [ %arraysize70210, %L245 ], [ %arraysize70, %L184 ]
  %value_phi102161 = phi float [ %value_phi102, %L245 ], [ 0.000000e+00, %L184 ]
  %133 = fadd float %93, %arrayref49
  %134 = fdiv float %aggregate_load_box.sroa.0.0.copyload, %91
  %135 = call float @llvm.sqrt.f32(float %value_phi102161)
  %136 = fsub float %91, %aggregate_load_box.sroa.0.0.copyload
  %137 = fcmp uge float %136, 0.000000e+00
  br i1 %137, label %L259, label %L257

L257:                                             ; preds = %L252
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 136709640595984 to {}*), float %136) #2
  unreachable

L259:                                             ; preds = %L252
  %138 = fadd float %91, %aggregate_load_box.sroa.0.0.copyload
  %139 = fcmp uge float %138, 0.000000e+00
  br i1 %139, label %L266, label %L264

L264:                                             ; preds = %L259
  call void @j_throw_complex_domainerror_1899({}* inttoptr (i64 136709640595984 to {}*), float %138) #2
  unreachable

L266:                                             ; preds = %L259
  %140 = call float @llvm.sqrt.f32(float %136)
  %141 = call float @llvm.sqrt.f32(float %138)
  %142 = fmul float %140, %141
  %143 = fdiv float %135, %142
  %144 = fmul float %134, %143
  %145 = fsub float %133, %144
  %bitcast_coercion = bitcast float %145 to i32
  %146 = icmp sgt i32 %bitcast_coercion, -1
  %147 = select i1 %146, float %145, float 0.000000e+00
  %148 = fcmp ord float %145, 0.000000e+00
  %149 = select i1 %148, float %147, float %145
  %150 = fadd float %133, %144
  %bitcast_coercion111 = bitcast float %150 to i32
  %151 = icmp sgt i32 %bitcast_coercion111, -1
  %152 = fcmp ord float %150, 0.000000e+00
  %153 = and i1 %152, %151
  %154 = select i1 %153, float 0.000000e+00, float %150
  %155 = fadd float %149, %154
  br label %L295

L291:                                             ; preds = %idxend46
  %156 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe452, i64 0, i64 2
  store {}* %getfield, {}** %156, align 16
  %157 = call float @j__sqrt_cold_1902({}* nonnull %0, float %arrayref49, float %value_phi40, i64 signext %value_phi9)
  br label %L295

L295:                                             ; preds = %L291, %L266, %L152
  %value_phi9221 = phi i64 [ %value_phi9222, %L266 ], [ %value_phi9224, %L291 ], [ %value_phi9224, %L152 ]
  %arraysize70208 = phi i64 [ %arraysize70209, %L266 ], [ %arraysize70211, %L291 ], [ %arraysize70211, %L152 ]
  %value_phi61 = phi float [ %155, %L266 ], [ %157, %L291 ], [ 0.000000e+00, %L152 ]
  %158 = fadd float %value_phi8, %value_phi61
  %.not149.not = icmp eq i64 %value_phi9, %arraylen
  %159 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not149.not, label %L307, label %L31

L307:                                             ; preds = %L295, %L17
  %value_phi9221.lcssa246 = phi i64 [ %value_phi9221.lcssa247, %L17 ], [ %value_phi9221, %L295 ]
  %arraysize70208.lcssa237 = phi i64 [ %arraysize70208.lcssa238, %L17 ], [ %arraysize70208, %L295 ]
  %value_phi65 = phi float [ %value_phi4, %L17 ], [ %158, %L295 ]
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
  %160 = load {}*, {}** %6, align 8
  %161 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %160, {}** %161, align 8
  ret float %value_phi68

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %162 = bitcast {}* %getfield16 to float**
  %arrayptr144 = load float*, float** %162, align 8
  %163 = getelementptr inbounds float, float* %arrayptr144, i64 %25
  %arrayref = load float, float* %163, align 4
  %164 = fcmp ord float %arrayref, 0.000000e+00
  %165 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr115 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %165, i64 0, i32 1
  %arraylen116 = load i64, i64* %arraylen_ptr115, align 8
  %.not156 = icmp eq i64 %arraylen116, 0
  br i1 %164, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48148 = load float*, float** %18, align 8
  %166 = getelementptr inbounds float, float* %arrayptr48148, i64 %25
  %arrayref49 = load float, float* %166, align 4
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %167 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %167 unordered, align 8
  %168 = bitcast {}* %getfield51 to i8*
  %getfield_addr56 = getelementptr inbounds i8, i8* %168, i64 24
  %169 = bitcast i8* %getfield_addr56 to {}**
  %getfield57 = load atomic {}*, {}** %169 unordered, align 8
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %170 = bitcast {}* %getfield57 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr58 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %170, i64 0, i32 1
  %arraylen59 = load i64, i64* %arraylen_ptr58, align 8
  %171 = fsub float %value_phi40, %value_phi40
  %172 = fcmp ord float %171, 0.000000e+00
  %173 = sitofp i64 %arraylen59 to float
  %174 = fmul float %173, 0x3980000000000000
  %175 = fcmp ole float %174, %value_phi40
  %176 = and i1 %172, %175
  %177 = fsub float %value_phi38, %value_phi38
  %178 = fcmp ord float %177, 0.000000e+00
  %179 = fcmp ole float %174, %value_phi38
  %180 = and i1 %178, %179
  %181 = and i1 %176, %180
  br i1 %181, label %L148, label %L291
}
