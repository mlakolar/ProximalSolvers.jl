; Function Attrs: noinline
define double @julia_pass_722({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe389 = alloca [3 x {}*], align 16
  %gcframe389.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe389, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe389 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe389 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe389, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe389.sub, {}*** %9, align 8
  %10 = bitcast {}* %0 to {}**
  %11 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %12 = icmp slt i64 %2, 1
  br i1 %12, label %L346, label %L17.preheader

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
  %21 = load i64, i64* %arraylen_ptr, align 8
  %22 = icmp eq i64 %21, 0
  br i1 %22, label %L346, label %L17

L17thread-pre-split:                              ; preds = %L335
  %23 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %21, %L17.preheader ]
  %value_phi3 = phi i64 [ %23, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi double [ %value_phi61, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L335, label %L31

L31:                                              ; preds = %L322, %L17
  %value_phi8 = phi double [ %273, %L322 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %274, %L322 ], [ 1, %L17 ]
  %getfield12 = load atomic {}*, {}** %14 unordered, align 8
  %getfield14 = load atomic {}*, {}** %16 unordered, align 8
  %getfield16 = load atomic {}*, {}** %17 unordered, align 8
  %24 = add nsw i64 %value_phi9, -1
  %25 = bitcast {}* %getfield16 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr17 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %25, i64 0, i32 1
  %arraylen18 = load i64, i64* %arraylen_ptr17, align 8
  %inbounds = icmp ult i64 %24, %arraylen18
  br i1 %inbounds, label %idxend, label %oob

L40:                                              ; preds = %idxend
  br i1 %.not158, label %L124, label %L54.lr.ph

L54.lr.ph:                                        ; preds = %L40
  %26 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr = getelementptr inbounds {}*, {}** %26, i64 3
  %27 = bitcast {}** %arraysize_ptr to i64*
  %arraysize = load i64, i64* %27, align 8
  %28 = mul i64 %arraysize, %24
  %29 = bitcast {}* %getfield12 to double**
  %arrayptr27145 = load double*, double** %29, align 8
  %30 = bitcast {}* %getfield14 to double**
  %arrayptr30146 = load double*, double** %30, align 8
  %min.iters.check305 = icmp ult i64 %arraylen115, 8
  br i1 %min.iters.check305, label %scalar.ph304, label %vector.ph306

vector.ph306:                                     ; preds = %L54.lr.ph
  %n.vec308 = and i64 %arraylen115, 9223372036854775800
  %31 = add nsw i64 %n.vec308, -8
  %32 = lshr exact i64 %31, 3
  %33 = add nuw nsw i64 %32, 1
  %xtraiter = and i64 %33, 1
  %34 = icmp eq i64 %31, 0
  br i1 %34, label %middle.block303.unr-lcssa, label %vector.ph306.new

vector.ph306.new:                                 ; preds = %vector.ph306
  %unroll_iter = and i64 %33, 4611686018427387902
  br label %vector.body311

vector.body311:                                   ; preds = %vector.body311, %vector.ph306.new
  %index312 = phi i64 [ 0, %vector.ph306.new ], [ %index.next323.1, %vector.body311 ]
  %vec.phi313 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306.new ], [ %67, %vector.body311 ]
  %vec.phi314 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306.new ], [ %68, %vector.body311 ]
  %vec.phi315 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306.new ], [ %71, %vector.body311 ]
  %vec.phi316 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306.new ], [ %72, %vector.body311 ]
  %vec.phi317 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306.new ], [ %75, %vector.body311 ]
  %vec.phi318 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306.new ], [ %76, %vector.body311 ]
  %niter = phi i64 [ 0, %vector.ph306.new ], [ %niter.next.1, %vector.body311 ]
  %35 = add i64 %28, %index312
  %36 = getelementptr inbounds double, double* %arrayptr27145, i64 %35
  %37 = bitcast double* %36 to <4 x double>*
  %wide.load319 = load <4 x double>, <4 x double>* %37, align 8
  %38 = getelementptr inbounds double, double* %36, i64 4
  %39 = bitcast double* %38 to <4 x double>*
  %wide.load320 = load <4 x double>, <4 x double>* %39, align 8
  %40 = getelementptr inbounds double, double* %arrayptr30146, i64 %index312
  %41 = bitcast double* %40 to <4 x double>*
  %wide.load321 = load <4 x double>, <4 x double>* %41, align 8
  %42 = getelementptr inbounds double, double* %40, i64 4
  %43 = bitcast double* %42 to <4 x double>*
  %wide.load322 = load <4 x double>, <4 x double>* %43, align 8
  %44 = fmul contract <4 x double> %wide.load319, %wide.load319
  %45 = fmul contract <4 x double> %wide.load320, %wide.load320
  %46 = fadd reassoc contract <4 x double> %vec.phi313, %44
  %47 = fadd reassoc contract <4 x double> %vec.phi314, %45
  %48 = fmul contract <4 x double> %wide.load319, %wide.load321
  %49 = fmul contract <4 x double> %wide.load320, %wide.load322
  %50 = fadd reassoc contract <4 x double> %vec.phi315, %48
  %51 = fadd reassoc contract <4 x double> %vec.phi316, %49
  %52 = fmul contract <4 x double> %wide.load321, %wide.load321
  %53 = fmul contract <4 x double> %wide.load322, %wide.load322
  %54 = fadd reassoc contract <4 x double> %vec.phi317, %52
  %55 = fadd reassoc contract <4 x double> %vec.phi318, %53
  %index.next323 = or i64 %index312, 8
  %56 = add i64 %28, %index.next323
  %57 = getelementptr inbounds double, double* %arrayptr27145, i64 %56
  %58 = bitcast double* %57 to <4 x double>*
  %wide.load319.1 = load <4 x double>, <4 x double>* %58, align 8
  %59 = getelementptr inbounds double, double* %57, i64 4
  %60 = bitcast double* %59 to <4 x double>*
  %wide.load320.1 = load <4 x double>, <4 x double>* %60, align 8
  %61 = getelementptr inbounds double, double* %arrayptr30146, i64 %index.next323
  %62 = bitcast double* %61 to <4 x double>*
  %wide.load321.1 = load <4 x double>, <4 x double>* %62, align 8
  %63 = getelementptr inbounds double, double* %61, i64 4
  %64 = bitcast double* %63 to <4 x double>*
  %wide.load322.1 = load <4 x double>, <4 x double>* %64, align 8
  %65 = fmul contract <4 x double> %wide.load319.1, %wide.load319.1
  %66 = fmul contract <4 x double> %wide.load320.1, %wide.load320.1
  %67 = fadd reassoc contract <4 x double> %46, %65
  %68 = fadd reassoc contract <4 x double> %47, %66
  %69 = fmul contract <4 x double> %wide.load319.1, %wide.load321.1
  %70 = fmul contract <4 x double> %wide.load320.1, %wide.load322.1
  %71 = fadd reassoc contract <4 x double> %50, %69
  %72 = fadd reassoc contract <4 x double> %51, %70
  %73 = fmul contract <4 x double> %wide.load321.1, %wide.load321.1
  %74 = fmul contract <4 x double> %wide.load322.1, %wide.load322.1
  %75 = fadd reassoc contract <4 x double> %54, %73
  %76 = fadd reassoc contract <4 x double> %55, %74
  %index.next323.1 = add nuw i64 %index312, 16
  %niter.next.1 = add i64 %niter, 2
  %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_iter
  br i1 %niter.ncmp.1, label %middle.block303.unr-lcssa, label %vector.body311

middle.block303.unr-lcssa:                        ; preds = %vector.body311, %vector.ph306
  %.lcssa336.ph = phi <4 x double> [ undef, %vector.ph306 ], [ %67, %vector.body311 ]
  %.lcssa335.ph = phi <4 x double> [ undef, %vector.ph306 ], [ %68, %vector.body311 ]
  %.lcssa334.ph = phi <4 x double> [ undef, %vector.ph306 ], [ %71, %vector.body311 ]
  %.lcssa333.ph = phi <4 x double> [ undef, %vector.ph306 ], [ %72, %vector.body311 ]
  %.lcssa332.ph = phi <4 x double> [ undef, %vector.ph306 ], [ %75, %vector.body311 ]
  %.lcssa.ph = phi <4 x double> [ undef, %vector.ph306 ], [ %76, %vector.body311 ]
  %index312.unr = phi i64 [ 0, %vector.ph306 ], [ %index.next323.1, %vector.body311 ]
  %vec.phi313.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %67, %vector.body311 ]
  %vec.phi314.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %68, %vector.body311 ]
  %vec.phi315.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %71, %vector.body311 ]
  %vec.phi316.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %72, %vector.body311 ]
  %vec.phi317.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %75, %vector.body311 ]
  %vec.phi318.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %76, %vector.body311 ]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %middle.block303, label %vector.body311.epil.preheader

vector.body311.epil.preheader:                    ; preds = %middle.block303.unr-lcssa
  %77 = add i64 %28, %index312.unr
  %78 = getelementptr inbounds double, double* %arrayptr27145, i64 %77
  %79 = bitcast double* %78 to <4 x double>*
  %wide.load319.epil = load <4 x double>, <4 x double>* %79, align 8
  %80 = getelementptr inbounds double, double* %78, i64 4
  %81 = bitcast double* %80 to <4 x double>*
  %wide.load320.epil = load <4 x double>, <4 x double>* %81, align 8
  %82 = getelementptr inbounds double, double* %arrayptr30146, i64 %index312.unr
  %83 = bitcast double* %82 to <4 x double>*
  %wide.load321.epil = load <4 x double>, <4 x double>* %83, align 8
  %84 = getelementptr inbounds double, double* %82, i64 4
  %85 = bitcast double* %84 to <4 x double>*
  %wide.load322.epil = load <4 x double>, <4 x double>* %85, align 8
  %86 = fmul contract <4 x double> %wide.load319.epil, %wide.load319.epil
  %87 = fmul contract <4 x double> %wide.load320.epil, %wide.load320.epil
  %88 = fadd reassoc contract <4 x double> %vec.phi313.unr, %86
  %89 = fadd reassoc contract <4 x double> %vec.phi314.unr, %87
  %90 = fmul contract <4 x double> %wide.load319.epil, %wide.load321.epil
  %91 = fmul contract <4 x double> %wide.load320.epil, %wide.load322.epil
  %92 = fadd reassoc contract <4 x double> %vec.phi315.unr, %90
  %93 = fadd reassoc contract <4 x double> %vec.phi316.unr, %91
  %94 = fmul contract <4 x double> %wide.load321.epil, %wide.load321.epil
  %95 = fmul contract <4 x double> %wide.load322.epil, %wide.load322.epil
  %96 = fadd reassoc contract <4 x double> %vec.phi317.unr, %94
  %97 = fadd reassoc contract <4 x double> %vec.phi318.unr, %95
  br label %middle.block303

middle.block303:                                  ; preds = %vector.body311.epil.preheader, %middle.block303.unr-lcssa
  %.lcssa336 = phi <4 x double> [ %.lcssa336.ph, %middle.block303.unr-lcssa ], [ %88, %vector.body311.epil.preheader ]
  %.lcssa335 = phi <4 x double> [ %.lcssa335.ph, %middle.block303.unr-lcssa ], [ %89, %vector.body311.epil.preheader ]
  %.lcssa334 = phi <4 x double> [ %.lcssa334.ph, %middle.block303.unr-lcssa ], [ %92, %vector.body311.epil.preheader ]
  %.lcssa333 = phi <4 x double> [ %.lcssa333.ph, %middle.block303.unr-lcssa ], [ %93, %vector.body311.epil.preheader ]
  %.lcssa332 = phi <4 x double> [ %.lcssa332.ph, %middle.block303.unr-lcssa ], [ %96, %vector.body311.epil.preheader ]
  %.lcssa = phi <4 x double> [ %.lcssa.ph, %middle.block303.unr-lcssa ], [ %97, %vector.body311.epil.preheader ]
  %bin.rdx328 = fadd reassoc contract <4 x double> %.lcssa, %.lcssa332
  %98 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx328)
  %bin.rdx326 = fadd reassoc contract <4 x double> %.lcssa333, %.lcssa334
  %99 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx326)
  %bin.rdx324 = fadd reassoc contract <4 x double> %.lcssa335, %.lcssa336
  %100 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx324)
  %cmp.n310 = icmp eq i64 %arraylen115, %n.vec308
  br i1 %cmp.n310, label %L124, label %scalar.ph304

scalar.ph304:                                     ; preds = %middle.block303, %L54.lr.ph
  %bc.resume.val309 = phi i64 [ %n.vec308, %middle.block303 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx325 = phi double [ %100, %middle.block303 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx327 = phi double [ %99, %middle.block303 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx329 = phi double [ %98, %middle.block303 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph304
  %value_phi25189 = phi double [ %bc.merge.rdx325, %scalar.ph304 ], [ %105, %L54 ]
  %value_phi24188 = phi i64 [ %bc.resume.val309, %scalar.ph304 ], [ %110, %L54 ]
  %value_phi23187 = phi double [ %bc.merge.rdx327, %scalar.ph304 ], [ %107, %L54 ]
  %value_phi22186 = phi double [ %bc.merge.rdx329, %scalar.ph304 ], [ %109, %L54 ]
  %101 = add i64 %28, %value_phi24188
  %102 = getelementptr inbounds double, double* %arrayptr27145, i64 %101
  %arrayref28 = load double, double* %102, align 8
  %103 = getelementptr inbounds double, double* %arrayptr30146, i64 %value_phi24188
  %arrayref31 = load double, double* %103, align 8
  %104 = fmul contract double %arrayref28, %arrayref28
  %105 = fadd reassoc contract double %value_phi25189, %104
  %106 = fmul contract double %arrayref28, %arrayref31
  %107 = fadd reassoc contract double %value_phi23187, %106
  %108 = fmul contract double %arrayref31, %arrayref31
  %109 = fadd reassoc contract double %value_phi22186, %108
  %110 = add nuw nsw i64 %value_phi24188, 1
  %exitcond.not = icmp eq i64 %110, %arraylen115
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not158, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %111 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr121 = getelementptr inbounds {}*, {}** %111, i64 3
  %112 = bitcast {}** %arraysize_ptr121 to i64*
  %arraysize122 = load i64, i64* %112, align 8
  %113 = mul i64 %arraysize122, %24
  %114 = bitcast {}* %getfield12 to double**
  %arrayptr125160 = load double*, double** %114, align 8
  %115 = bitcast {}* %getfield14 to double**
  %arrayptr128161 = load double*, double** %115, align 8
  %min.iters.check282 = icmp ult i64 %arraylen115, 8
  br i1 %min.iters.check282, label %scalar.ph281, label %vector.ph283

vector.ph283:                                     ; preds = %L96.lr.ph
  %n.vec285 = and i64 %arraylen115, 9223372036854775800
  %116 = add nsw i64 %n.vec285, -8
  %117 = lshr exact i64 %116, 3
  %118 = add nuw nsw i64 %117, 1
  %xtraiter380 = and i64 %118, 1
  %119 = icmp eq i64 %116, 0
  br i1 %119, label %middle.block280.unr-lcssa, label %vector.ph283.new

vector.ph283.new:                                 ; preds = %vector.ph283
  %unroll_iter386 = and i64 %118, 4611686018427387902
  br label %vector.body288

vector.body288:                                   ; preds = %vector.body288, %vector.ph283.new
  %index289 = phi i64 [ 0, %vector.ph283.new ], [ %index.next298.1, %vector.body288 ]
  %vec.phi290 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283.new ], [ %148, %vector.body288 ]
  %vec.phi291 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283.new ], [ %149, %vector.body288 ]
  %vec.phi292 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283.new ], [ %152, %vector.body288 ]
  %vec.phi293 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283.new ], [ %153, %vector.body288 ]
  %niter387 = phi i64 [ 0, %vector.ph283.new ], [ %niter387.next.1, %vector.body288 ]
  %120 = add i64 %113, %index289
  %121 = getelementptr inbounds double, double* %arrayptr125160, i64 %120
  %122 = bitcast double* %121 to <4 x double>*
  %wide.load294 = load <4 x double>, <4 x double>* %122, align 8
  %123 = getelementptr inbounds double, double* %121, i64 4
  %124 = bitcast double* %123 to <4 x double>*
  %wide.load295 = load <4 x double>, <4 x double>* %124, align 8
  %125 = getelementptr inbounds double, double* %arrayptr128161, i64 %index289
  %126 = bitcast double* %125 to <4 x double>*
  %wide.load296 = load <4 x double>, <4 x double>* %126, align 8
  %127 = getelementptr inbounds double, double* %125, i64 4
  %128 = bitcast double* %127 to <4 x double>*
  %wide.load297 = load <4 x double>, <4 x double>* %128, align 8
  %129 = fmul contract <4 x double> %wide.load294, %wide.load296
  %130 = fmul contract <4 x double> %wide.load295, %wide.load297
  %131 = fadd reassoc contract <4 x double> %vec.phi290, %129
  %132 = fadd reassoc contract <4 x double> %vec.phi291, %130
  %133 = fmul contract <4 x double> %wide.load296, %wide.load296
  %134 = fmul contract <4 x double> %wide.load297, %wide.load297
  %135 = fadd reassoc contract <4 x double> %vec.phi292, %133
  %136 = fadd reassoc contract <4 x double> %vec.phi293, %134
  %index.next298 = or i64 %index289, 8
  %137 = add i64 %113, %index.next298
  %138 = getelementptr inbounds double, double* %arrayptr125160, i64 %137
  %139 = bitcast double* %138 to <4 x double>*
  %wide.load294.1 = load <4 x double>, <4 x double>* %139, align 8
  %140 = getelementptr inbounds double, double* %138, i64 4
  %141 = bitcast double* %140 to <4 x double>*
  %wide.load295.1 = load <4 x double>, <4 x double>* %141, align 8
  %142 = getelementptr inbounds double, double* %arrayptr128161, i64 %index.next298
  %143 = bitcast double* %142 to <4 x double>*
  %wide.load296.1 = load <4 x double>, <4 x double>* %143, align 8
  %144 = getelementptr inbounds double, double* %142, i64 4
  %145 = bitcast double* %144 to <4 x double>*
  %wide.load297.1 = load <4 x double>, <4 x double>* %145, align 8
  %146 = fmul contract <4 x double> %wide.load294.1, %wide.load296.1
  %147 = fmul contract <4 x double> %wide.load295.1, %wide.load297.1
  %148 = fadd reassoc contract <4 x double> %131, %146
  %149 = fadd reassoc contract <4 x double> %132, %147
  %150 = fmul contract <4 x double> %wide.load296.1, %wide.load296.1
  %151 = fmul contract <4 x double> %wide.load297.1, %wide.load297.1
  %152 = fadd reassoc contract <4 x double> %135, %150
  %153 = fadd reassoc contract <4 x double> %136, %151
  %index.next298.1 = add nuw i64 %index289, 16
  %niter387.next.1 = add i64 %niter387, 2
  %niter387.ncmp.1 = icmp eq i64 %niter387.next.1, %unroll_iter386
  br i1 %niter387.ncmp.1, label %middle.block280.unr-lcssa, label %vector.body288

middle.block280.unr-lcssa:                        ; preds = %vector.body288, %vector.ph283
  %.lcssa343.ph = phi <4 x double> [ undef, %vector.ph283 ], [ %148, %vector.body288 ]
  %.lcssa342.ph = phi <4 x double> [ undef, %vector.ph283 ], [ %149, %vector.body288 ]
  %.lcssa341.ph = phi <4 x double> [ undef, %vector.ph283 ], [ %152, %vector.body288 ]
  %.lcssa340.ph = phi <4 x double> [ undef, %vector.ph283 ], [ %153, %vector.body288 ]
  %index289.unr = phi i64 [ 0, %vector.ph283 ], [ %index.next298.1, %vector.body288 ]
  %vec.phi290.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %148, %vector.body288 ]
  %vec.phi291.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %149, %vector.body288 ]
  %vec.phi292.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %152, %vector.body288 ]
  %vec.phi293.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %153, %vector.body288 ]
  %lcmp.mod381.not = icmp eq i64 %xtraiter380, 0
  br i1 %lcmp.mod381.not, label %middle.block280, label %vector.body288.epil.preheader

vector.body288.epil.preheader:                    ; preds = %middle.block280.unr-lcssa
  %154 = add i64 %113, %index289.unr
  %155 = getelementptr inbounds double, double* %arrayptr125160, i64 %154
  %156 = bitcast double* %155 to <4 x double>*
  %wide.load294.epil = load <4 x double>, <4 x double>* %156, align 8
  %157 = getelementptr inbounds double, double* %155, i64 4
  %158 = bitcast double* %157 to <4 x double>*
  %wide.load295.epil = load <4 x double>, <4 x double>* %158, align 8
  %159 = getelementptr inbounds double, double* %arrayptr128161, i64 %index289.unr
  %160 = bitcast double* %159 to <4 x double>*
  %wide.load296.epil = load <4 x double>, <4 x double>* %160, align 8
  %161 = getelementptr inbounds double, double* %159, i64 4
  %162 = bitcast double* %161 to <4 x double>*
  %wide.load297.epil = load <4 x double>, <4 x double>* %162, align 8
  %163 = fmul contract <4 x double> %wide.load294.epil, %wide.load296.epil
  %164 = fmul contract <4 x double> %wide.load295.epil, %wide.load297.epil
  %165 = fadd reassoc contract <4 x double> %vec.phi290.unr, %163
  %166 = fadd reassoc contract <4 x double> %vec.phi291.unr, %164
  %167 = fmul contract <4 x double> %wide.load296.epil, %wide.load296.epil
  %168 = fmul contract <4 x double> %wide.load297.epil, %wide.load297.epil
  %169 = fadd reassoc contract <4 x double> %vec.phi292.unr, %167
  %170 = fadd reassoc contract <4 x double> %vec.phi293.unr, %168
  br label %middle.block280

middle.block280:                                  ; preds = %vector.body288.epil.preheader, %middle.block280.unr-lcssa
  %.lcssa343 = phi <4 x double> [ %.lcssa343.ph, %middle.block280.unr-lcssa ], [ %165, %vector.body288.epil.preheader ]
  %.lcssa342 = phi <4 x double> [ %.lcssa342.ph, %middle.block280.unr-lcssa ], [ %166, %vector.body288.epil.preheader ]
  %.lcssa341 = phi <4 x double> [ %.lcssa341.ph, %middle.block280.unr-lcssa ], [ %169, %vector.body288.epil.preheader ]
  %.lcssa340 = phi <4 x double> [ %.lcssa340.ph, %middle.block280.unr-lcssa ], [ %170, %vector.body288.epil.preheader ]
  %bin.rdx301 = fadd reassoc contract <4 x double> %.lcssa340, %.lcssa341
  %171 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx301)
  %bin.rdx299 = fadd reassoc contract <4 x double> %.lcssa342, %.lcssa343
  %172 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx299)
  %cmp.n287 = icmp eq i64 %arraylen115, %n.vec285
  br i1 %cmp.n287, label %L124, label %scalar.ph281

scalar.ph281:                                     ; preds = %middle.block280, %L96.lr.ph
  %bc.resume.val286 = phi i64 [ %n.vec285, %middle.block280 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx300 = phi double [ %172, %middle.block280 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx302 = phi double [ %171, %middle.block280 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph281
  %value_phi120195 = phi i64 [ %bc.resume.val286, %scalar.ph281 ], [ %180, %L96 ]
  %value_phi119194 = phi double [ %bc.merge.rdx300, %scalar.ph281 ], [ %177, %L96 ]
  %value_phi118193 = phi double [ %bc.merge.rdx302, %scalar.ph281 ], [ %179, %L96 ]
  %173 = add i64 %113, %value_phi120195
  %174 = getelementptr inbounds double, double* %arrayptr125160, i64 %173
  %arrayref126 = load double, double* %174, align 8
  %175 = getelementptr inbounds double, double* %arrayptr128161, i64 %value_phi120195
  %arrayref129 = load double, double* %175, align 8
  %176 = fmul contract double %arrayref126, %arrayref129
  %177 = fadd reassoc contract double %value_phi119194, %176
  %178 = fmul contract double %arrayref129, %arrayref129
  %179 = fadd reassoc contract double %value_phi118193, %178
  %180 = add nuw nsw i64 %value_phi120195, 1
  %exitcond202.not = icmp eq i64 %180, %arraylen115
  br i1 %exitcond202.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block280, %L83, %L54, %middle.block303, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %171, %middle.block280 ], [ %98, %middle.block303 ], [ %179, %L96 ], [ %109, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %172, %middle.block280 ], [ %99, %middle.block303 ], [ %177, %L96 ], [ %107, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block280 ], [ %100, %middle.block303 ], [ %arrayref, %L96 ], [ %105, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %24, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L144:                                             ; preds = %idxend46
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %181 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %181, label %L150, label %L148

L148:                                             ; preds = %L144
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 140312453360144 to {}*), double %value_phi40) #3
  unreachable

L150:                                             ; preds = %L144
  %182 = call double @llvm.sqrt.f64(double %value_phi40)
  %183 = fcmp ugt double %182, %aggregate_load_box.sroa.0.0.copyload
  br i1 %183, label %L155, label %L322

L155:                                             ; preds = %L150
  %184 = fdiv double %value_phi39, %value_phi40
  %185 = fadd double %184, %arrayref49
  %186 = fmul double %value_phi39, %184
  %187 = fsub double %value_phi38, %186
  %188 = fmul double %value_phi38, 6.250000e-02
  %189 = fcmp uge double %187, %188
  br i1 %189, label %L210, label %L162

L162:                                             ; preds = %L155
  %.not150 = icmp eq i64 %arraylen55, 0
  br i1 %.not150, label %L199, label %L176.lr.ph

L176.lr.ph:                                       ; preds = %L162
  %190 = bitcast {}* %getfield51 to {}**
  %getfield66 = load atomic {}*, {}** %190 unordered, align 8
  %191 = bitcast {}* %getfield53 to double**
  %arrayptr76152 = load double*, double** %191, align 8
  %192 = bitcast {}* %getfield66 to {}**
  %arraysize_ptr78 = getelementptr inbounds {}*, {}** %192, i64 3
  %193 = bitcast {}** %arraysize_ptr78 to i64*
  %arraysize79 = load i64, i64* %193, align 8
  %194 = mul i64 %arraysize79, %24
  %195 = bitcast {}* %getfield66 to double**
  %arrayptr82153 = load double*, double** %195, align 8
  %min.iters.check = icmp ult i64 %arraylen55, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L176.lr.ph
  %n.vec = and i64 %arraylen55, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %184, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %225, %vector.body ]
  %vec.phi262 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %226, %vector.body ]
  %vec.phi263 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %227, %vector.body ]
  %vec.phi264 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %228, %vector.body ]
  %196 = getelementptr inbounds double, double* %arrayptr76152, i64 %index
  %197 = bitcast double* %196 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %197, align 8
  %198 = getelementptr inbounds double, double* %196, i64 4
  %199 = bitcast double* %198 to <4 x double>*
  %wide.load265 = load <4 x double>, <4 x double>* %199, align 8
  %200 = getelementptr inbounds double, double* %196, i64 8
  %201 = bitcast double* %200 to <4 x double>*
  %wide.load266 = load <4 x double>, <4 x double>* %201, align 8
  %202 = getelementptr inbounds double, double* %196, i64 12
  %203 = bitcast double* %202 to <4 x double>*
  %wide.load267 = load <4 x double>, <4 x double>* %203, align 8
  %204 = add i64 %194, %index
  %205 = getelementptr inbounds double, double* %arrayptr82153, i64 %204
  %206 = bitcast double* %205 to <4 x double>*
  %wide.load268 = load <4 x double>, <4 x double>* %206, align 8
  %207 = getelementptr inbounds double, double* %205, i64 4
  %208 = bitcast double* %207 to <4 x double>*
  %wide.load269 = load <4 x double>, <4 x double>* %208, align 8
  %209 = getelementptr inbounds double, double* %205, i64 8
  %210 = bitcast double* %209 to <4 x double>*
  %wide.load270 = load <4 x double>, <4 x double>* %210, align 8
  %211 = getelementptr inbounds double, double* %205, i64 12
  %212 = bitcast double* %211 to <4 x double>*
  %wide.load271 = load <4 x double>, <4 x double>* %212, align 8
  %213 = fmul <4 x double> %broadcast.splat, %wide.load268
  %214 = fmul <4 x double> %broadcast.splat, %wide.load269
  %215 = fmul <4 x double> %broadcast.splat, %wide.load270
  %216 = fmul <4 x double> %broadcast.splat, %wide.load271
  %217 = fsub <4 x double> %wide.load, %213
  %218 = fsub <4 x double> %wide.load265, %214
  %219 = fsub <4 x double> %wide.load266, %215
  %220 = fsub <4 x double> %wide.load267, %216
  %221 = fmul contract <4 x double> %217, %217
  %222 = fmul contract <4 x double> %218, %218
  %223 = fmul contract <4 x double> %219, %219
  %224 = fmul contract <4 x double> %220, %220
  %225 = fadd reassoc contract <4 x double> %vec.phi, %221
  %226 = fadd reassoc contract <4 x double> %vec.phi262, %222
  %227 = fadd reassoc contract <4 x double> %vec.phi263, %223
  %228 = fadd reassoc contract <4 x double> %vec.phi264, %224
  %index.next = add nuw i64 %index, 16
  %229 = icmp eq i64 %index.next, %n.vec
  br i1 %229, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %226, %225
  %bin.rdx278 = fadd reassoc contract <4 x double> %227, %bin.rdx
  %bin.rdx279 = fadd reassoc contract <4 x double> %228, %bin.rdx278
  %230 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx279)
  %cmp.n = icmp eq i64 %arraylen55, %n.vec
  br i1 %cmp.n, label %L199, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L176.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L176.lr.ph ]
  %bc.merge.rdx = phi double [ %230, %middle.block ], [ 0.000000e+00, %L176.lr.ph ]
  br label %L176

L176:                                             ; preds = %L176, %scalar.ph
  %value_phi74200 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %238, %L176 ]
  %value_phi73199 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %237, %L176 ]
  %231 = getelementptr inbounds double, double* %arrayptr76152, i64 %value_phi74200
  %arrayref77 = load double, double* %231, align 8
  %232 = add i64 %194, %value_phi74200
  %233 = getelementptr inbounds double, double* %arrayptr82153, i64 %232
  %arrayref83 = load double, double* %233, align 8
  %234 = fmul double %184, %arrayref83
  %235 = fsub double %arrayref77, %234
  %236 = fmul contract double %235, %235
  %237 = fadd reassoc contract double %value_phi73199, %236
  %238 = add nuw nsw i64 %value_phi74200, 1
  %exitcond203.not = icmp eq i64 %238, %arraylen55
  br i1 %exitcond203.not, label %L199, label %L176

L199:                                             ; preds = %L176, %middle.block, %L162
  %value_phi85 = phi double [ 0.000000e+00, %L162 ], [ %230, %middle.block ], [ %237, %L176 ]
  %239 = fsub double %value_phi85, %value_phi85
  %240 = fcmp uno double %239, 0.000000e+00
  %241 = fcmp ugt double %288, %value_phi85
  %242 = or i1 %241, %240
  br i1 %242, label %L208, label %L210

L208:                                             ; preds = %L199
  %243 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe389, i64 0, i64 2
  store {}* %getfield, {}** %243, align 16
  %244 = call double @j__sqrt_offrange_step_728({}* nonnull %0, double %arrayref49, i64 signext %value_phi9)
  br label %L322

L210:                                             ; preds = %L199, %L155
  %value_phi87 = phi double [ %187, %L155 ], [ %value_phi85, %L199 ]
  %245 = fcmp uge double %value_phi87, 0.000000e+00
  br i1 %245, label %L215, label %L213

L213:                                             ; preds = %L210
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 140312453360144 to {}*), double %value_phi87) #3
  unreachable

L215:                                             ; preds = %L210
  %246 = call double @llvm.sqrt.f64(double %value_phi87)
  %247 = fsub double %182, %aggregate_load_box.sroa.0.0.copyload
  %248 = fcmp uge double %247, 0.000000e+00
  br i1 %248, label %L222, label %L220

L220:                                             ; preds = %L215
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 140312453360144 to {}*), double %247) #3
  unreachable

L222:                                             ; preds = %L215
  %249 = fadd double %182, %aggregate_load_box.sroa.0.0.copyload
  %250 = fcmp uge double %249, 0.000000e+00
  br i1 %250, label %L229, label %L227

L227:                                             ; preds = %L222
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 140312453360144 to {}*), double %249) #3
  unreachable

L229:                                             ; preds = %L222
  %251 = call double @llvm.sqrt.f64(double %247)
  %252 = call double @llvm.sqrt.f64(double %249)
  %253 = fmul double %251, %252
  %254 = fmul double %182, %253
  %255 = fdiv double %246, %254
  %256 = fmul double %aggregate_load_box.sroa.0.0.copyload, %255
  %257 = fcmp oge double %254, 0x10000000000000
  %258 = fcmp oge double %255, 0x10000000000000
  %259 = fcmp ole double %255, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %258, %259
  %260 = and i1 %257, %narrow
  %261 = fcmp oge double %256, 0x10000000000000
  %262 = fcmp ole double %256, 0x7FEFFFFFFFFFFFFF
  %narrow154 = and i1 %261, %262
  %263 = and i1 %260, %narrow154
  br i1 %263, label %L263, label %L318

L263:                                             ; preds = %L229
  %264 = fneg double %256
  %.inv = fcmp ogt double %185, %264
  %265 = select i1 %.inv, double %185, double %264
  %.inv156 = fcmp olt double %265, %256
  %266 = select i1 %.inv156, double %265, double %256
  %267 = fsub double %185, %266
  %268 = fadd double %267, 0.000000e+00
  br label %L322

L318:                                             ; preds = %L229
  %269 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe389, i64 0, i64 2
  store {}* %getfield, {}** %269, align 16
  %270 = call double @j__sqrt_band_step_727(double %185, double %182, double %aggregate_load_box.sroa.0.0.copyload, double %246, i64 signext 0)
  br label %L322

L320:                                             ; preds = %idxend46
  %271 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe389, i64 0, i64 2
  store {}* %getfield, {}** %271, align 16
  %272 = call double @j__sqrt_offrange_step_728({}* nonnull %0, double %arrayref49, i64 signext %value_phi9)
  br label %L322

L322:                                             ; preds = %L320, %L318, %L263, %L208, %L150
  %value_phi57 = phi double [ %244, %L208 ], [ %270, %L318 ], [ %272, %L320 ], [ 0.000000e+00, %L150 ], [ %268, %L263 ]
  %273 = fadd double %value_phi8, %value_phi57
  %.not148.not = icmp eq i64 %value_phi9, %arraylen
  %274 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not148.not, label %L335, label %L31

L335:                                             ; preds = %L322, %L17
  %value_phi61 = phi double [ %value_phi4, %L17 ], [ %273, %L322 ]
  %.not149 = icmp eq i64 %value_phi3, %11
  br i1 %.not149, label %L346, label %L17thread-pre-split

L346:                                             ; preds = %L335, %L17.preheader, %top
  %value_phi64 = phi double [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi61, %L335 ]
  %275 = load {}*, {}** %6, align 8
  %276 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %275, {}** %276, align 8
  ret double %value_phi64

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %277 = bitcast {}* %getfield16 to double**
  %arrayptr143 = load double*, double** %277, align 8
  %278 = getelementptr inbounds double, double* %arrayptr143, i64 %24
  %arrayref = load double, double* %278, align 8
  %279 = fcmp ord double %arrayref, 0.000000e+00
  %280 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr114 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %280, i64 0, i32 1
  %arraylen115 = load i64, i64* %arraylen_ptr114, align 8
  %.not158 = icmp eq i64 %arraylen115, 0
  br i1 %279, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48147 = load double*, double** %18, align 8
  %281 = getelementptr inbounds double, double* %arrayptr48147, i64 %24
  %arrayref49 = load double, double* %281, align 8
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %282 = bitcast {}* %getfield51 to i8*
  %getfield_addr52 = getelementptr inbounds i8, i8* %282, i64 24
  %283 = bitcast i8* %getfield_addr52 to {}**
  %getfield53 = load atomic {}*, {}** %283 unordered, align 8
  %284 = bitcast {}* %getfield53 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr54 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %284, i64 0, i32 1
  %arraylen55 = load i64, i64* %arraylen_ptr54, align 8
  %285 = fsub double %value_phi40, %value_phi40
  %286 = fcmp ord double %285, 0.000000e+00
  %287 = sitofp i64 %arraylen55 to double
  %288 = fmul double %287, 0x350000000000000
  %289 = fcmp ole double %288, %value_phi40
  %290 = and i1 %286, %289
  %291 = fsub double %value_phi38, %value_phi38
  %292 = fcmp ord double %291, 0.000000e+00
  %293 = fcmp ole double %288, %value_phi38
  %294 = and i1 %292, %293
  %295 = and i1 %290, %294
  br i1 %295, label %L144, label %L320
}
