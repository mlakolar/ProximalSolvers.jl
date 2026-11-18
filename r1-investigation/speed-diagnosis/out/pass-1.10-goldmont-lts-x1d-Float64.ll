; Function Attrs: noinline
define double @julia_pass_1068({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe477 = alloca [3 x {}*], align 16
  %gcframe477.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe477, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe477 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %newstruct74 = alloca { [1 x [1 x i64]], i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe477 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe477, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe477.sub, {}*** %9, align 8
  %10 = bitcast {}* %0 to {}**
  %11 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %12 = icmp slt i64 %2, 1
  br i1 %12, label %L316, label %L17.preheader

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
  %18 = bitcast {}* %1 to double**
  %19 = bitcast {}* %0 to i8*
  %20 = getelementptr inbounds i8, i8* %19, i64 8
  %aggregate_load_box.sroa.0.0..sroa_idx = bitcast i8* %20 to double*
  %memcpy_refined_dst = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct74, i64 0, i32 0, i64 0, i64 0
  %21 = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct74, i64 0, i32 1
  %22 = load i64, i64* %arraylen_ptr, align 8
  %23 = icmp eq i64 %22, 0
  br i1 %23, label %L316.loopexit, label %L17

L17thread-pre-split:                              ; preds = %L305
  %24 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %22, %L17.preheader ]
  %value_phi9221.lcssa247 = phi i64 [ %value_phi9221.lcssa246, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %arraysize70208.lcssa238 = phi i64 [ %arraysize70208.lcssa237, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %value_phi3 = phi i64 [ %24, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi double [ %value_phi65, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L305, label %L31

L31:                                              ; preds = %L293, %L17
  %value_phi9224 = phi i64 [ %value_phi9221, %L293 ], [ %value_phi9221.lcssa247, %L17 ]
  %arraysize70211 = phi i64 [ %arraysize70208, %L293 ], [ %arraysize70208.lcssa238, %L17 ]
  %value_phi8 = phi double [ %184, %L293 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %185, %L293 ], [ 1, %L17 ]
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
  %30 = bitcast {}* %getfield12 to double**
  %arrayptr27146 = load double*, double** %30, align 8
  %31 = bitcast {}* %getfield14 to double**
  %arrayptr30147 = load double*, double** %31, align 8
  %min.iters.check401 = icmp ult i64 %arraylen116, 8
  br i1 %min.iters.check401, label %scalar.ph400, label %vector.ph402

vector.ph402:                                     ; preds = %L54.lr.ph
  %n.vec404 = and i64 %arraylen116, 9223372036854775800
  br label %vector.body407

vector.body407:                                   ; preds = %vector.body407, %vector.ph402
  %index408 = phi i64 [ 0, %vector.ph402 ], [ %index.next419, %vector.body407 ]
  %vec.phi409 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %43, %vector.body407 ]
  %vec.phi410 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %44, %vector.body407 ]
  %vec.phi411 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %47, %vector.body407 ]
  %vec.phi412 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %48, %vector.body407 ]
  %vec.phi413 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %51, %vector.body407 ]
  %vec.phi414 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %52, %vector.body407 ]
  %32 = add i64 %29, %index408
  %33 = getelementptr inbounds double, double* %arrayptr27146, i64 %32
  %34 = bitcast double* %33 to <4 x double>*
  %wide.load415 = load <4 x double>, <4 x double>* %34, align 8
  %35 = getelementptr inbounds double, double* %33, i64 4
  %36 = bitcast double* %35 to <4 x double>*
  %wide.load416 = load <4 x double>, <4 x double>* %36, align 8
  %37 = getelementptr inbounds double, double* %arrayptr30147, i64 %index408
  %38 = bitcast double* %37 to <4 x double>*
  %wide.load417 = load <4 x double>, <4 x double>* %38, align 8
  %39 = getelementptr inbounds double, double* %37, i64 4
  %40 = bitcast double* %39 to <4 x double>*
  %wide.load418 = load <4 x double>, <4 x double>* %40, align 8
  %41 = fmul contract <4 x double> %wide.load415, %wide.load415
  %42 = fmul contract <4 x double> %wide.load416, %wide.load416
  %43 = fadd reassoc contract <4 x double> %vec.phi409, %41
  %44 = fadd reassoc contract <4 x double> %vec.phi410, %42
  %45 = fmul contract <4 x double> %wide.load415, %wide.load417
  %46 = fmul contract <4 x double> %wide.load416, %wide.load418
  %47 = fadd reassoc contract <4 x double> %vec.phi411, %45
  %48 = fadd reassoc contract <4 x double> %vec.phi412, %46
  %49 = fmul contract <4 x double> %wide.load417, %wide.load417
  %50 = fmul contract <4 x double> %wide.load418, %wide.load418
  %51 = fadd reassoc contract <4 x double> %vec.phi413, %49
  %52 = fadd reassoc contract <4 x double> %vec.phi414, %50
  %index.next419 = add nuw i64 %index408, 8
  %53 = icmp eq i64 %index.next419, %n.vec404
  br i1 %53, label %middle.block399, label %vector.body407

middle.block399:                                  ; preds = %vector.body407
  %bin.rdx424 = fadd reassoc contract <4 x double> %52, %51
  %54 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx424)
  %bin.rdx422 = fadd reassoc contract <4 x double> %48, %47
  %55 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx422)
  %bin.rdx420 = fadd reassoc contract <4 x double> %44, %43
  %56 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx420)
  %cmp.n406 = icmp eq i64 %arraylen116, %n.vec404
  br i1 %cmp.n406, label %L124, label %scalar.ph400

scalar.ph400:                                     ; preds = %middle.block399, %L54.lr.ph
  %bc.resume.val405 = phi i64 [ %n.vec404, %middle.block399 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx421 = phi double [ %56, %middle.block399 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx423 = phi double [ %55, %middle.block399 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx425 = phi double [ %54, %middle.block399 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph400
  %value_phi25195 = phi double [ %bc.merge.rdx421, %scalar.ph400 ], [ %61, %L54 ]
  %value_phi24194 = phi i64 [ %bc.resume.val405, %scalar.ph400 ], [ %66, %L54 ]
  %value_phi23193 = phi double [ %bc.merge.rdx423, %scalar.ph400 ], [ %63, %L54 ]
  %value_phi22192 = phi double [ %bc.merge.rdx425, %scalar.ph400 ], [ %65, %L54 ]
  %57 = add i64 %29, %value_phi24194
  %58 = getelementptr inbounds double, double* %arrayptr27146, i64 %57
  %arrayref28 = load double, double* %58, align 8
  %59 = getelementptr inbounds double, double* %arrayptr30147, i64 %value_phi24194
  %arrayref31 = load double, double* %59, align 8
  %60 = fmul contract double %arrayref28, %arrayref28
  %61 = fadd reassoc contract double %value_phi25195, %60
  %62 = fmul contract double %arrayref28, %arrayref31
  %63 = fadd reassoc contract double %value_phi23193, %62
  %64 = fmul contract double %arrayref31, %arrayref31
  %65 = fadd reassoc contract double %value_phi22192, %64
  %66 = add nuw nsw i64 %value_phi24194, 1
  %exitcond.not = icmp eq i64 %66, %arraylen116
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not156, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %67 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr122 = getelementptr inbounds {}*, {}** %67, i64 3
  %68 = bitcast {}** %arraysize_ptr122 to i64*
  %arraysize123 = load i64, i64* %68, align 8
  %69 = mul i64 %arraysize123, %25
  %70 = bitcast {}* %getfield12 to double**
  %arrayptr126158 = load double*, double** %70, align 8
  %71 = bitcast {}* %getfield14 to double**
  %arrayptr129159 = load double*, double** %71, align 8
  %min.iters.check378 = icmp ult i64 %arraylen116, 8
  br i1 %min.iters.check378, label %scalar.ph377, label %vector.ph379

vector.ph379:                                     ; preds = %L96.lr.ph
  %n.vec381 = and i64 %arraylen116, 9223372036854775800
  br label %vector.body384

vector.body384:                                   ; preds = %vector.body384, %vector.ph379
  %index385 = phi i64 [ 0, %vector.ph379 ], [ %index.next394, %vector.body384 ]
  %vec.phi386 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %83, %vector.body384 ]
  %vec.phi387 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %84, %vector.body384 ]
  %vec.phi388 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %87, %vector.body384 ]
  %vec.phi389 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %88, %vector.body384 ]
  %72 = add i64 %69, %index385
  %73 = getelementptr inbounds double, double* %arrayptr126158, i64 %72
  %74 = bitcast double* %73 to <4 x double>*
  %wide.load390 = load <4 x double>, <4 x double>* %74, align 8
  %75 = getelementptr inbounds double, double* %73, i64 4
  %76 = bitcast double* %75 to <4 x double>*
  %wide.load391 = load <4 x double>, <4 x double>* %76, align 8
  %77 = getelementptr inbounds double, double* %arrayptr129159, i64 %index385
  %78 = bitcast double* %77 to <4 x double>*
  %wide.load392 = load <4 x double>, <4 x double>* %78, align 8
  %79 = getelementptr inbounds double, double* %77, i64 4
  %80 = bitcast double* %79 to <4 x double>*
  %wide.load393 = load <4 x double>, <4 x double>* %80, align 8
  %81 = fmul contract <4 x double> %wide.load390, %wide.load392
  %82 = fmul contract <4 x double> %wide.load391, %wide.load393
  %83 = fadd reassoc contract <4 x double> %vec.phi386, %81
  %84 = fadd reassoc contract <4 x double> %vec.phi387, %82
  %85 = fmul contract <4 x double> %wide.load392, %wide.load392
  %86 = fmul contract <4 x double> %wide.load393, %wide.load393
  %87 = fadd reassoc contract <4 x double> %vec.phi388, %85
  %88 = fadd reassoc contract <4 x double> %vec.phi389, %86
  %index.next394 = add nuw i64 %index385, 8
  %89 = icmp eq i64 %index.next394, %n.vec381
  br i1 %89, label %middle.block376, label %vector.body384

middle.block376:                                  ; preds = %vector.body384
  %bin.rdx397 = fadd reassoc contract <4 x double> %88, %87
  %90 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx397)
  %bin.rdx395 = fadd reassoc contract <4 x double> %84, %83
  %91 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx395)
  %cmp.n383 = icmp eq i64 %arraylen116, %n.vec381
  br i1 %cmp.n383, label %L124, label %scalar.ph377

scalar.ph377:                                     ; preds = %middle.block376, %L96.lr.ph
  %bc.resume.val382 = phi i64 [ %n.vec381, %middle.block376 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx396 = phi double [ %91, %middle.block376 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx398 = phi double [ %90, %middle.block376 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph377
  %value_phi121201 = phi i64 [ %bc.resume.val382, %scalar.ph377 ], [ %99, %L96 ]
  %value_phi120200 = phi double [ %bc.merge.rdx396, %scalar.ph377 ], [ %96, %L96 ]
  %value_phi119199 = phi double [ %bc.merge.rdx398, %scalar.ph377 ], [ %98, %L96 ]
  %92 = add i64 %69, %value_phi121201
  %93 = getelementptr inbounds double, double* %arrayptr126158, i64 %92
  %arrayref127 = load double, double* %93, align 8
  %94 = getelementptr inbounds double, double* %arrayptr129159, i64 %value_phi121201
  %arrayref130 = load double, double* %94, align 8
  %95 = fmul contract double %arrayref127, %arrayref130
  %96 = fadd reassoc contract double %value_phi120200, %95
  %97 = fmul contract double %arrayref130, %arrayref130
  %98 = fadd reassoc contract double %value_phi119199, %97
  %99 = add nuw nsw i64 %value_phi121201, 1
  %exitcond256.not = icmp eq i64 %99, %arraylen116
  br i1 %exitcond256.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block376, %L83, %L54, %middle.block399, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %90, %middle.block376 ], [ %54, %middle.block399 ], [ %98, %L96 ], [ %65, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %91, %middle.block376 ], [ %55, %middle.block399 ], [ %96, %L96 ], [ %63, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block376 ], [ %56, %middle.block399 ], [ %arrayref, %L96 ], [ %61, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %25, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L148:                                             ; preds = %idxend46
  %100 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %100, label %L152, label %L150

L150:                                             ; preds = %L148
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 136709640595984 to {}*), double %value_phi40) #3
  unreachable

L152:                                             ; preds = %L148
  %101 = call double @llvm.sqrt.f64(double %value_phi40)
  %102 = fcmp ugt double %101, %aggregate_load_box.sroa.0.0.copyload
  br i1 %102, label %L157, label %L293

L157:                                             ; preds = %L152
  %103 = fdiv double %value_phi39, %value_phi40
  %104 = fmul double %value_phi39, %103
  %105 = fsub double %value_phi38, %104
  %106 = fmul double %value_phi38, 6.250000e-02
  %107 = fcmp uge double %105, %106
  br i1 %107, label %L245, label %L163

L163:                                             ; preds = %L157
  %108 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr69 = getelementptr inbounds {}*, {}** %108, i64 3
  %109 = bitcast {}** %arraysize_ptr69 to i64*
  %arraysize70 = load i64, i64* %109, align 8
  %arraysize_ptr75 = getelementptr inbounds {}*, {}** %108, i64 4
  %110 = bitcast {}** %arraysize_ptr75 to i64*
  %arraysize76 = load i64, i64* %110, align 8
  %.not151 = icmp ult i64 %25, %arraysize76
  br i1 %.not151, label %L184, label %L181

L181:                                             ; preds = %L163
  store i64 %arraysize70, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %21, align 8
  %111 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe477, i64 0, i64 2
  store {}* %getfield53, {}** %111, align 16
  call void @j_throw_boundserror_1073({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct74) #3
  unreachable

L184:                                             ; preds = %L163
  %112 = mul i64 %arraysize70, %25
  %.not152 = icmp eq i64 %arraylen59, 0
  br i1 %.not152, label %L252, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L184
  %113 = bitcast {}* %getfield57 to double**
  %arrayptr92154 = load double*, double** %113, align 8
  %114 = bitcast {}* %getfield53 to double**
  %arrayptr96155 = load double*, double** %114, align 8
  %min.iters.check = icmp ult i64 %arraylen59, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen59, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %103, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %144, %vector.body ]
  %vec.phi358 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %145, %vector.body ]
  %vec.phi359 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %146, %vector.body ]
  %vec.phi360 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %147, %vector.body ]
  %115 = getelementptr inbounds double, double* %arrayptr92154, i64 %index
  %116 = bitcast double* %115 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %116, align 8
  %117 = getelementptr inbounds double, double* %115, i64 4
  %118 = bitcast double* %117 to <4 x double>*
  %wide.load361 = load <4 x double>, <4 x double>* %118, align 8
  %119 = getelementptr inbounds double, double* %115, i64 8
  %120 = bitcast double* %119 to <4 x double>*
  %wide.load362 = load <4 x double>, <4 x double>* %120, align 8
  %121 = getelementptr inbounds double, double* %115, i64 12
  %122 = bitcast double* %121 to <4 x double>*
  %wide.load363 = load <4 x double>, <4 x double>* %122, align 8
  %123 = add i64 %index, %112
  %124 = getelementptr inbounds double, double* %arrayptr96155, i64 %123
  %125 = bitcast double* %124 to <4 x double>*
  %wide.load364 = load <4 x double>, <4 x double>* %125, align 8
  %126 = getelementptr inbounds double, double* %124, i64 4
  %127 = bitcast double* %126 to <4 x double>*
  %wide.load365 = load <4 x double>, <4 x double>* %127, align 8
  %128 = getelementptr inbounds double, double* %124, i64 8
  %129 = bitcast double* %128 to <4 x double>*
  %wide.load366 = load <4 x double>, <4 x double>* %129, align 8
  %130 = getelementptr inbounds double, double* %124, i64 12
  %131 = bitcast double* %130 to <4 x double>*
  %wide.load367 = load <4 x double>, <4 x double>* %131, align 8
  %132 = fmul <4 x double> %broadcast.splat, %wide.load364
  %133 = fmul <4 x double> %broadcast.splat, %wide.load365
  %134 = fmul <4 x double> %broadcast.splat, %wide.load366
  %135 = fmul <4 x double> %broadcast.splat, %wide.load367
  %136 = fsub <4 x double> %wide.load, %132
  %137 = fsub <4 x double> %wide.load361, %133
  %138 = fsub <4 x double> %wide.load362, %134
  %139 = fsub <4 x double> %wide.load363, %135
  %140 = fmul contract <4 x double> %136, %136
  %141 = fmul contract <4 x double> %137, %137
  %142 = fmul contract <4 x double> %138, %138
  %143 = fmul contract <4 x double> %139, %139
  %144 = fadd reassoc contract <4 x double> %vec.phi, %140
  %145 = fadd reassoc contract <4 x double> %vec.phi358, %141
  %146 = fadd reassoc contract <4 x double> %vec.phi359, %142
  %147 = fadd reassoc contract <4 x double> %vec.phi360, %143
  %index.next = add nuw i64 %index, 16
  %148 = icmp eq i64 %index.next, %n.vec
  br i1 %148, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %145, %144
  %bin.rdx374 = fadd reassoc contract <4 x double> %146, %bin.rdx
  %bin.rdx375 = fadd reassoc contract <4 x double> %147, %bin.rdx374
  %149 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx375)
  %cmp.n = icmp eq i64 %arraylen59, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi double [ %149, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90206 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %157, %L208 ]
  %value_phi89205 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %156, %L208 ]
  %150 = getelementptr inbounds double, double* %arrayptr92154, i64 %value_phi90206
  %arrayref93 = load double, double* %150, align 8
  %151 = add i64 %value_phi90206, %112
  %152 = getelementptr inbounds double, double* %arrayptr96155, i64 %151
  %arrayref97 = load double, double* %152, align 8
  %153 = fmul double %103, %arrayref97
  %154 = fsub double %arrayref93, %153
  %155 = fmul contract double %154, %154
  %156 = fadd reassoc contract double %value_phi89205, %155
  %157 = add nuw nsw i64 %value_phi90206, 1
  %exitcond257.not = icmp eq i64 %157, %arraylen59
  br i1 %exitcond257.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L157
  %value_phi9223 = phi i64 [ %value_phi9224, %L157 ], [ %value_phi9, %middle.block ], [ %value_phi9, %L208 ]
  %arraysize70210 = phi i64 [ %arraysize70211, %L157 ], [ %arraysize70, %middle.block ], [ %arraysize70, %L208 ]
  %value_phi102 = phi double [ %105, %L157 ], [ %149, %middle.block ], [ %156, %L208 ]
  %158 = fcmp uge double %value_phi102, 0.000000e+00
  br i1 %158, label %L252, label %L250

L250:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 136709640595984 to {}*), double %value_phi102) #3
  unreachable

L252:                                             ; preds = %L245, %L184
  %value_phi9222 = phi i64 [ %value_phi9223, %L245 ], [ %value_phi9, %L184 ]
  %arraysize70209 = phi i64 [ %arraysize70210, %L245 ], [ %arraysize70, %L184 ]
  %value_phi102161 = phi double [ %value_phi102, %L245 ], [ 0.000000e+00, %L184 ]
  %159 = fadd double %103, %arrayref49
  %160 = fdiv double %aggregate_load_box.sroa.0.0.copyload, %101
  %161 = call double @llvm.sqrt.f64(double %value_phi102161)
  %162 = fsub double %101, %aggregate_load_box.sroa.0.0.copyload
  %163 = fcmp uge double %162, 0.000000e+00
  br i1 %163, label %L259, label %L257

L257:                                             ; preds = %L252
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 136709640595984 to {}*), double %162) #3
  unreachable

L259:                                             ; preds = %L252
  %164 = fadd double %101, %aggregate_load_box.sroa.0.0.copyload
  %165 = fcmp uge double %164, 0.000000e+00
  br i1 %165, label %L266, label %L264

L264:                                             ; preds = %L259
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 136709640595984 to {}*), double %164) #3
  unreachable

L266:                                             ; preds = %L259
  %166 = call double @llvm.sqrt.f64(double %162)
  %167 = call double @llvm.sqrt.f64(double %164)
  %168 = fmul double %166, %167
  %169 = fdiv double %161, %168
  %170 = fmul double %160, %169
  %171 = fsub double %159, %170
  %bitcast_coercion = bitcast double %171 to i64
  %172 = icmp sgt i64 %bitcast_coercion, -1
  %173 = select i1 %172, double %171, double 0.000000e+00
  %174 = fcmp ord double %171, 0.000000e+00
  %175 = select i1 %174, double %173, double %171
  %176 = fadd double %159, %170
  %bitcast_coercion111 = bitcast double %176 to i64
  %177 = icmp sgt i64 %bitcast_coercion111, -1
  %178 = fcmp ord double %176, 0.000000e+00
  %179 = and i1 %178, %177
  %180 = select i1 %179, double 0.000000e+00, double %176
  %181 = fadd double %175, %180
  br label %L293

L289:                                             ; preds = %idxend46
  %182 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe477, i64 0, i64 2
  store {}* %getfield, {}** %182, align 16
  %183 = call double @j__sqrt_cold_1074({}* nonnull %0, double %arrayref49, double %value_phi40, i64 signext %value_phi9)
  br label %L293

L293:                                             ; preds = %L289, %L266, %L152
  %value_phi9221 = phi i64 [ %value_phi9222, %L266 ], [ %value_phi9224, %L289 ], [ %value_phi9224, %L152 ]
  %arraysize70208 = phi i64 [ %arraysize70209, %L266 ], [ %arraysize70211, %L289 ], [ %arraysize70211, %L152 ]
  %value_phi61 = phi double [ %181, %L266 ], [ %183, %L289 ], [ 0.000000e+00, %L152 ]
  %184 = fadd double %value_phi8, %value_phi61
  %.not149.not = icmp eq i64 %value_phi9, %arraylen
  %185 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not149.not, label %L305, label %L31

L305:                                             ; preds = %L293, %L17
  %value_phi9221.lcssa246 = phi i64 [ %value_phi9221.lcssa247, %L17 ], [ %value_phi9221, %L293 ]
  %arraysize70208.lcssa237 = phi i64 [ %arraysize70208.lcssa238, %L17 ], [ %arraysize70208, %L293 ]
  %value_phi65 = phi double [ %value_phi4, %L17 ], [ %184, %L293 ]
  %.not150 = icmp eq i64 %value_phi3, %11
  br i1 %.not150, label %L316.loopexit, label %L17thread-pre-split

L316.loopexit:                                    ; preds = %L305, %L17.preheader
  %.us-phi = phi i64 [ undef, %L17.preheader ], [ %value_phi9221.lcssa246, %L305 ]
  %.us-phi254 = phi i64 [ undef, %L17.preheader ], [ %arraysize70208.lcssa237, %L305 ]
  %.us-phi255 = phi double [ 0.000000e+00, %L17.preheader ], [ %value_phi65, %L305 ]
  store i64 %.us-phi254, i64* %memcpy_refined_dst, align 8
  store i64 %.us-phi, i64* %21, align 8
  br label %L316

L316:                                             ; preds = %L316.loopexit, %top
  %value_phi68 = phi double [ 0.000000e+00, %top ], [ %.us-phi255, %L316.loopexit ]
  %186 = load {}*, {}** %6, align 8
  %187 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %186, {}** %187, align 8
  ret double %value_phi68

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %188 = bitcast {}* %getfield16 to double**
  %arrayptr144 = load double*, double** %188, align 8
  %189 = getelementptr inbounds double, double* %arrayptr144, i64 %25
  %arrayref = load double, double* %189, align 8
  %190 = fcmp ord double %arrayref, 0.000000e+00
  %191 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr115 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %191, i64 0, i32 1
  %arraylen116 = load i64, i64* %arraylen_ptr115, align 8
  %.not156 = icmp eq i64 %arraylen116, 0
  br i1 %190, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48148 = load double*, double** %18, align 8
  %192 = getelementptr inbounds double, double* %arrayptr48148, i64 %25
  %arrayref49 = load double, double* %192, align 8
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %193 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %193 unordered, align 8
  %194 = bitcast {}* %getfield51 to i8*
  %getfield_addr56 = getelementptr inbounds i8, i8* %194, i64 24
  %195 = bitcast i8* %getfield_addr56 to {}**
  %getfield57 = load atomic {}*, {}** %195 unordered, align 8
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %196 = bitcast {}* %getfield57 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr58 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %196, i64 0, i32 1
  %arraylen59 = load i64, i64* %arraylen_ptr58, align 8
  %197 = fsub double %value_phi40, %value_phi40
  %198 = fcmp ord double %197, 0.000000e+00
  %199 = sitofp i64 %arraylen59 to double
  %200 = fmul double %199, 0x350000000000000
  %201 = fcmp ole double %200, %value_phi40
  %202 = and i1 %198, %201
  %203 = fsub double %value_phi38, %value_phi38
  %204 = fcmp ord double %203, 0.000000e+00
  %205 = fcmp ole double %200, %value_phi38
  %206 = and i1 %204, %205
  %207 = and i1 %202, %206
  br i1 %207, label %L148, label %L289
}
