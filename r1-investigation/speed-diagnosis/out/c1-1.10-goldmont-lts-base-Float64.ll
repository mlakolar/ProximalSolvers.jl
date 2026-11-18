; Function Attrs: noinline
define double @julia_pass_722({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe375 = alloca [3 x {}*], align 16
  %gcframe375.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe375, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe375 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe375 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe375, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe375.sub, {}*** %9, align 8
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
  %value_phi8 = phi double [ %191, %L322 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %192, %L322 ], [ 1, %L17 ]
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
  br label %vector.body311

vector.body311:                                   ; preds = %vector.body311, %vector.ph306
  %index312 = phi i64 [ 0, %vector.ph306 ], [ %index.next323, %vector.body311 ]
  %vec.phi313 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %42, %vector.body311 ]
  %vec.phi314 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %43, %vector.body311 ]
  %vec.phi315 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %46, %vector.body311 ]
  %vec.phi316 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %47, %vector.body311 ]
  %vec.phi317 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %50, %vector.body311 ]
  %vec.phi318 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph306 ], [ %51, %vector.body311 ]
  %31 = add i64 %28, %index312
  %32 = getelementptr inbounds double, double* %arrayptr27145, i64 %31
  %33 = bitcast double* %32 to <4 x double>*
  %wide.load319 = load <4 x double>, <4 x double>* %33, align 8
  %34 = getelementptr inbounds double, double* %32, i64 4
  %35 = bitcast double* %34 to <4 x double>*
  %wide.load320 = load <4 x double>, <4 x double>* %35, align 8
  %36 = getelementptr inbounds double, double* %arrayptr30146, i64 %index312
  %37 = bitcast double* %36 to <4 x double>*
  %wide.load321 = load <4 x double>, <4 x double>* %37, align 8
  %38 = getelementptr inbounds double, double* %36, i64 4
  %39 = bitcast double* %38 to <4 x double>*
  %wide.load322 = load <4 x double>, <4 x double>* %39, align 8
  %40 = fmul contract <4 x double> %wide.load319, %wide.load319
  %41 = fmul contract <4 x double> %wide.load320, %wide.load320
  %42 = fadd reassoc contract <4 x double> %vec.phi313, %40
  %43 = fadd reassoc contract <4 x double> %vec.phi314, %41
  %44 = fmul contract <4 x double> %wide.load319, %wide.load321
  %45 = fmul contract <4 x double> %wide.load320, %wide.load322
  %46 = fadd reassoc contract <4 x double> %vec.phi315, %44
  %47 = fadd reassoc contract <4 x double> %vec.phi316, %45
  %48 = fmul contract <4 x double> %wide.load321, %wide.load321
  %49 = fmul contract <4 x double> %wide.load322, %wide.load322
  %50 = fadd reassoc contract <4 x double> %vec.phi317, %48
  %51 = fadd reassoc contract <4 x double> %vec.phi318, %49
  %index.next323 = add nuw i64 %index312, 8
  %52 = icmp eq i64 %index.next323, %n.vec308
  br i1 %52, label %middle.block303, label %vector.body311

middle.block303:                                  ; preds = %vector.body311
  %bin.rdx328 = fadd reassoc contract <4 x double> %51, %50
  %53 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx328)
  %bin.rdx326 = fadd reassoc contract <4 x double> %47, %46
  %54 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx326)
  %bin.rdx324 = fadd reassoc contract <4 x double> %43, %42
  %55 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx324)
  %cmp.n310 = icmp eq i64 %arraylen115, %n.vec308
  br i1 %cmp.n310, label %L124, label %scalar.ph304

scalar.ph304:                                     ; preds = %middle.block303, %L54.lr.ph
  %bc.resume.val309 = phi i64 [ %n.vec308, %middle.block303 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx325 = phi double [ %55, %middle.block303 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx327 = phi double [ %54, %middle.block303 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx329 = phi double [ %53, %middle.block303 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph304
  %value_phi25189 = phi double [ %bc.merge.rdx325, %scalar.ph304 ], [ %60, %L54 ]
  %value_phi24188 = phi i64 [ %bc.resume.val309, %scalar.ph304 ], [ %65, %L54 ]
  %value_phi23187 = phi double [ %bc.merge.rdx327, %scalar.ph304 ], [ %62, %L54 ]
  %value_phi22186 = phi double [ %bc.merge.rdx329, %scalar.ph304 ], [ %64, %L54 ]
  %56 = add i64 %28, %value_phi24188
  %57 = getelementptr inbounds double, double* %arrayptr27145, i64 %56
  %arrayref28 = load double, double* %57, align 8
  %58 = getelementptr inbounds double, double* %arrayptr30146, i64 %value_phi24188
  %arrayref31 = load double, double* %58, align 8
  %59 = fmul contract double %arrayref28, %arrayref28
  %60 = fadd reassoc contract double %value_phi25189, %59
  %61 = fmul contract double %arrayref28, %arrayref31
  %62 = fadd reassoc contract double %value_phi23187, %61
  %63 = fmul contract double %arrayref31, %arrayref31
  %64 = fadd reassoc contract double %value_phi22186, %63
  %65 = add nuw nsw i64 %value_phi24188, 1
  %exitcond.not = icmp eq i64 %65, %arraylen115
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not158, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %66 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr121 = getelementptr inbounds {}*, {}** %66, i64 3
  %67 = bitcast {}** %arraysize_ptr121 to i64*
  %arraysize122 = load i64, i64* %67, align 8
  %68 = mul i64 %arraysize122, %24
  %69 = bitcast {}* %getfield12 to double**
  %arrayptr125160 = load double*, double** %69, align 8
  %70 = bitcast {}* %getfield14 to double**
  %arrayptr128161 = load double*, double** %70, align 8
  %min.iters.check282 = icmp ult i64 %arraylen115, 8
  br i1 %min.iters.check282, label %scalar.ph281, label %vector.ph283

vector.ph283:                                     ; preds = %L96.lr.ph
  %n.vec285 = and i64 %arraylen115, 9223372036854775800
  br label %vector.body288

vector.body288:                                   ; preds = %vector.body288, %vector.ph283
  %index289 = phi i64 [ 0, %vector.ph283 ], [ %index.next298, %vector.body288 ]
  %vec.phi290 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %82, %vector.body288 ]
  %vec.phi291 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %83, %vector.body288 ]
  %vec.phi292 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %86, %vector.body288 ]
  %vec.phi293 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph283 ], [ %87, %vector.body288 ]
  %71 = add i64 %68, %index289
  %72 = getelementptr inbounds double, double* %arrayptr125160, i64 %71
  %73 = bitcast double* %72 to <4 x double>*
  %wide.load294 = load <4 x double>, <4 x double>* %73, align 8
  %74 = getelementptr inbounds double, double* %72, i64 4
  %75 = bitcast double* %74 to <4 x double>*
  %wide.load295 = load <4 x double>, <4 x double>* %75, align 8
  %76 = getelementptr inbounds double, double* %arrayptr128161, i64 %index289
  %77 = bitcast double* %76 to <4 x double>*
  %wide.load296 = load <4 x double>, <4 x double>* %77, align 8
  %78 = getelementptr inbounds double, double* %76, i64 4
  %79 = bitcast double* %78 to <4 x double>*
  %wide.load297 = load <4 x double>, <4 x double>* %79, align 8
  %80 = fmul contract <4 x double> %wide.load294, %wide.load296
  %81 = fmul contract <4 x double> %wide.load295, %wide.load297
  %82 = fadd reassoc contract <4 x double> %vec.phi290, %80
  %83 = fadd reassoc contract <4 x double> %vec.phi291, %81
  %84 = fmul contract <4 x double> %wide.load296, %wide.load296
  %85 = fmul contract <4 x double> %wide.load297, %wide.load297
  %86 = fadd reassoc contract <4 x double> %vec.phi292, %84
  %87 = fadd reassoc contract <4 x double> %vec.phi293, %85
  %index.next298 = add nuw i64 %index289, 8
  %88 = icmp eq i64 %index.next298, %n.vec285
  br i1 %88, label %middle.block280, label %vector.body288

middle.block280:                                  ; preds = %vector.body288
  %bin.rdx301 = fadd reassoc contract <4 x double> %87, %86
  %89 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx301)
  %bin.rdx299 = fadd reassoc contract <4 x double> %83, %82
  %90 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx299)
  %cmp.n287 = icmp eq i64 %arraylen115, %n.vec285
  br i1 %cmp.n287, label %L124, label %scalar.ph281

scalar.ph281:                                     ; preds = %middle.block280, %L96.lr.ph
  %bc.resume.val286 = phi i64 [ %n.vec285, %middle.block280 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx300 = phi double [ %90, %middle.block280 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx302 = phi double [ %89, %middle.block280 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph281
  %value_phi120195 = phi i64 [ %bc.resume.val286, %scalar.ph281 ], [ %98, %L96 ]
  %value_phi119194 = phi double [ %bc.merge.rdx300, %scalar.ph281 ], [ %95, %L96 ]
  %value_phi118193 = phi double [ %bc.merge.rdx302, %scalar.ph281 ], [ %97, %L96 ]
  %91 = add i64 %68, %value_phi120195
  %92 = getelementptr inbounds double, double* %arrayptr125160, i64 %91
  %arrayref126 = load double, double* %92, align 8
  %93 = getelementptr inbounds double, double* %arrayptr128161, i64 %value_phi120195
  %arrayref129 = load double, double* %93, align 8
  %94 = fmul contract double %arrayref126, %arrayref129
  %95 = fadd reassoc contract double %value_phi119194, %94
  %96 = fmul contract double %arrayref129, %arrayref129
  %97 = fadd reassoc contract double %value_phi118193, %96
  %98 = add nuw nsw i64 %value_phi120195, 1
  %exitcond202.not = icmp eq i64 %98, %arraylen115
  br i1 %exitcond202.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block280, %L83, %L54, %middle.block303, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %89, %middle.block280 ], [ %53, %middle.block303 ], [ %97, %L96 ], [ %64, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %90, %middle.block280 ], [ %54, %middle.block303 ], [ %95, %L96 ], [ %62, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block280 ], [ %55, %middle.block303 ], [ %arrayref, %L96 ], [ %60, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %24, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L144:                                             ; preds = %idxend46
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %99 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %99, label %L150, label %L148

L148:                                             ; preds = %L144
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 126417930070544 to {}*), double %value_phi40) #3
  unreachable

L150:                                             ; preds = %L144
  %100 = call double @llvm.sqrt.f64(double %value_phi40)
  %101 = fcmp ugt double %100, %aggregate_load_box.sroa.0.0.copyload
  br i1 %101, label %L155, label %L322

L155:                                             ; preds = %L150
  %102 = fdiv double %value_phi39, %value_phi40
  %103 = fadd double %102, %arrayref49
  %104 = fmul double %value_phi39, %102
  %105 = fsub double %value_phi38, %104
  %106 = fmul double %value_phi38, 6.250000e-02
  %107 = fcmp uge double %105, %106
  br i1 %107, label %L210, label %L162

L162:                                             ; preds = %L155
  %.not150 = icmp eq i64 %arraylen55, 0
  br i1 %.not150, label %L199, label %L176.lr.ph

L176.lr.ph:                                       ; preds = %L162
  %108 = bitcast {}* %getfield51 to {}**
  %getfield66 = load atomic {}*, {}** %108 unordered, align 8
  %109 = bitcast {}* %getfield53 to double**
  %arrayptr76152 = load double*, double** %109, align 8
  %110 = bitcast {}* %getfield66 to {}**
  %arraysize_ptr78 = getelementptr inbounds {}*, {}** %110, i64 3
  %111 = bitcast {}** %arraysize_ptr78 to i64*
  %arraysize79 = load i64, i64* %111, align 8
  %112 = mul i64 %arraysize79, %24
  %113 = bitcast {}* %getfield66 to double**
  %arrayptr82153 = load double*, double** %113, align 8
  %min.iters.check = icmp ult i64 %arraylen55, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L176.lr.ph
  %n.vec = and i64 %arraylen55, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %102, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %143, %vector.body ]
  %vec.phi262 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %144, %vector.body ]
  %vec.phi263 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %145, %vector.body ]
  %vec.phi264 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %146, %vector.body ]
  %114 = getelementptr inbounds double, double* %arrayptr76152, i64 %index
  %115 = bitcast double* %114 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %115, align 8
  %116 = getelementptr inbounds double, double* %114, i64 4
  %117 = bitcast double* %116 to <4 x double>*
  %wide.load265 = load <4 x double>, <4 x double>* %117, align 8
  %118 = getelementptr inbounds double, double* %114, i64 8
  %119 = bitcast double* %118 to <4 x double>*
  %wide.load266 = load <4 x double>, <4 x double>* %119, align 8
  %120 = getelementptr inbounds double, double* %114, i64 12
  %121 = bitcast double* %120 to <4 x double>*
  %wide.load267 = load <4 x double>, <4 x double>* %121, align 8
  %122 = add i64 %112, %index
  %123 = getelementptr inbounds double, double* %arrayptr82153, i64 %122
  %124 = bitcast double* %123 to <4 x double>*
  %wide.load268 = load <4 x double>, <4 x double>* %124, align 8
  %125 = getelementptr inbounds double, double* %123, i64 4
  %126 = bitcast double* %125 to <4 x double>*
  %wide.load269 = load <4 x double>, <4 x double>* %126, align 8
  %127 = getelementptr inbounds double, double* %123, i64 8
  %128 = bitcast double* %127 to <4 x double>*
  %wide.load270 = load <4 x double>, <4 x double>* %128, align 8
  %129 = getelementptr inbounds double, double* %123, i64 12
  %130 = bitcast double* %129 to <4 x double>*
  %wide.load271 = load <4 x double>, <4 x double>* %130, align 8
  %131 = fmul <4 x double> %broadcast.splat, %wide.load268
  %132 = fmul <4 x double> %broadcast.splat, %wide.load269
  %133 = fmul <4 x double> %broadcast.splat, %wide.load270
  %134 = fmul <4 x double> %broadcast.splat, %wide.load271
  %135 = fsub <4 x double> %wide.load, %131
  %136 = fsub <4 x double> %wide.load265, %132
  %137 = fsub <4 x double> %wide.load266, %133
  %138 = fsub <4 x double> %wide.load267, %134
  %139 = fmul contract <4 x double> %135, %135
  %140 = fmul contract <4 x double> %136, %136
  %141 = fmul contract <4 x double> %137, %137
  %142 = fmul contract <4 x double> %138, %138
  %143 = fadd reassoc contract <4 x double> %vec.phi, %139
  %144 = fadd reassoc contract <4 x double> %vec.phi262, %140
  %145 = fadd reassoc contract <4 x double> %vec.phi263, %141
  %146 = fadd reassoc contract <4 x double> %vec.phi264, %142
  %index.next = add nuw i64 %index, 16
  %147 = icmp eq i64 %index.next, %n.vec
  br i1 %147, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %144, %143
  %bin.rdx278 = fadd reassoc contract <4 x double> %145, %bin.rdx
  %bin.rdx279 = fadd reassoc contract <4 x double> %146, %bin.rdx278
  %148 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx279)
  %cmp.n = icmp eq i64 %arraylen55, %n.vec
  br i1 %cmp.n, label %L199, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L176.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L176.lr.ph ]
  %bc.merge.rdx = phi double [ %148, %middle.block ], [ 0.000000e+00, %L176.lr.ph ]
  br label %L176

L176:                                             ; preds = %L176, %scalar.ph
  %value_phi74200 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %156, %L176 ]
  %value_phi73199 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %155, %L176 ]
  %149 = getelementptr inbounds double, double* %arrayptr76152, i64 %value_phi74200
  %arrayref77 = load double, double* %149, align 8
  %150 = add i64 %112, %value_phi74200
  %151 = getelementptr inbounds double, double* %arrayptr82153, i64 %150
  %arrayref83 = load double, double* %151, align 8
  %152 = fmul double %102, %arrayref83
  %153 = fsub double %arrayref77, %152
  %154 = fmul contract double %153, %153
  %155 = fadd reassoc contract double %value_phi73199, %154
  %156 = add nuw nsw i64 %value_phi74200, 1
  %exitcond203.not = icmp eq i64 %156, %arraylen55
  br i1 %exitcond203.not, label %L199, label %L176

L199:                                             ; preds = %L176, %middle.block, %L162
  %value_phi85 = phi double [ 0.000000e+00, %L162 ], [ %148, %middle.block ], [ %155, %L176 ]
  %157 = fsub double %value_phi85, %value_phi85
  %158 = fcmp uno double %157, 0.000000e+00
  %159 = fcmp ugt double %206, %value_phi85
  %160 = or i1 %159, %158
  br i1 %160, label %L208, label %L210

L208:                                             ; preds = %L199
  %161 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe375, i64 0, i64 2
  store {}* %getfield, {}** %161, align 16
  %162 = call double @j__sqrt_offrange_step_728({}* nonnull %0, double %arrayref49, i64 signext %value_phi9)
  br label %L322

L210:                                             ; preds = %L199, %L155
  %value_phi87 = phi double [ %105, %L155 ], [ %value_phi85, %L199 ]
  %163 = fcmp uge double %value_phi87, 0.000000e+00
  br i1 %163, label %L215, label %L213

L213:                                             ; preds = %L210
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 126417930070544 to {}*), double %value_phi87) #3
  unreachable

L215:                                             ; preds = %L210
  %164 = call double @llvm.sqrt.f64(double %value_phi87)
  %165 = fsub double %100, %aggregate_load_box.sroa.0.0.copyload
  %166 = fcmp uge double %165, 0.000000e+00
  br i1 %166, label %L222, label %L220

L220:                                             ; preds = %L215
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 126417930070544 to {}*), double %165) #3
  unreachable

L222:                                             ; preds = %L215
  %167 = fadd double %100, %aggregate_load_box.sroa.0.0.copyload
  %168 = fcmp uge double %167, 0.000000e+00
  br i1 %168, label %L229, label %L227

L227:                                             ; preds = %L222
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 126417930070544 to {}*), double %167) #3
  unreachable

L229:                                             ; preds = %L222
  %169 = call double @llvm.sqrt.f64(double %165)
  %170 = call double @llvm.sqrt.f64(double %167)
  %171 = fmul double %169, %170
  %172 = fmul double %100, %171
  %173 = fdiv double %164, %172
  %174 = fmul double %aggregate_load_box.sroa.0.0.copyload, %173
  %175 = fcmp oge double %172, 0x10000000000000
  %176 = fcmp oge double %173, 0x10000000000000
  %177 = fcmp ole double %173, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %176, %177
  %178 = and i1 %175, %narrow
  %179 = fcmp oge double %174, 0x10000000000000
  %180 = fcmp ole double %174, 0x7FEFFFFFFFFFFFFF
  %narrow154 = and i1 %179, %180
  %181 = and i1 %178, %narrow154
  br i1 %181, label %L263, label %L318

L263:                                             ; preds = %L229
  %182 = fneg double %174
  %.inv = fcmp ogt double %103, %182
  %183 = select i1 %.inv, double %103, double %182
  %.inv156 = fcmp olt double %183, %174
  %184 = select i1 %.inv156, double %183, double %174
  %185 = fsub double %103, %184
  %186 = fadd double %185, 0.000000e+00
  br label %L322

L318:                                             ; preds = %L229
  %187 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe375, i64 0, i64 2
  store {}* %getfield, {}** %187, align 16
  %188 = call double @j__sqrt_band_step_727(double %103, double %100, double %aggregate_load_box.sroa.0.0.copyload, double %164, i64 signext 0)
  br label %L322

L320:                                             ; preds = %idxend46
  %189 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe375, i64 0, i64 2
  store {}* %getfield, {}** %189, align 16
  %190 = call double @j__sqrt_offrange_step_728({}* nonnull %0, double %arrayref49, i64 signext %value_phi9)
  br label %L322

L322:                                             ; preds = %L320, %L318, %L263, %L208, %L150
  %value_phi57 = phi double [ %162, %L208 ], [ %188, %L318 ], [ %190, %L320 ], [ 0.000000e+00, %L150 ], [ %186, %L263 ]
  %191 = fadd double %value_phi8, %value_phi57
  %.not148.not = icmp eq i64 %value_phi9, %arraylen
  %192 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not148.not, label %L335, label %L31

L335:                                             ; preds = %L322, %L17
  %value_phi61 = phi double [ %value_phi4, %L17 ], [ %191, %L322 ]
  %.not149 = icmp eq i64 %value_phi3, %11
  br i1 %.not149, label %L346, label %L17thread-pre-split

L346:                                             ; preds = %L335, %L17.preheader, %top
  %value_phi64 = phi double [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi61, %L335 ]
  %193 = load {}*, {}** %6, align 8
  %194 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %193, {}** %194, align 8
  ret double %value_phi64

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %195 = bitcast {}* %getfield16 to double**
  %arrayptr143 = load double*, double** %195, align 8
  %196 = getelementptr inbounds double, double* %arrayptr143, i64 %24
  %arrayref = load double, double* %196, align 8
  %197 = fcmp ord double %arrayref, 0.000000e+00
  %198 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr114 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %198, i64 0, i32 1
  %arraylen115 = load i64, i64* %arraylen_ptr114, align 8
  %.not158 = icmp eq i64 %arraylen115, 0
  br i1 %197, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48147 = load double*, double** %18, align 8
  %199 = getelementptr inbounds double, double* %arrayptr48147, i64 %24
  %arrayref49 = load double, double* %199, align 8
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %200 = bitcast {}* %getfield51 to i8*
  %getfield_addr52 = getelementptr inbounds i8, i8* %200, i64 24
  %201 = bitcast i8* %getfield_addr52 to {}**
  %getfield53 = load atomic {}*, {}** %201 unordered, align 8
  %202 = bitcast {}* %getfield53 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr54 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %202, i64 0, i32 1
  %arraylen55 = load i64, i64* %arraylen_ptr54, align 8
  %203 = fsub double %value_phi40, %value_phi40
  %204 = fcmp ord double %203, 0.000000e+00
  %205 = sitofp i64 %arraylen55 to double
  %206 = fmul double %205, 0x350000000000000
  %207 = fcmp ole double %206, %value_phi40
  %208 = and i1 %204, %207
  %209 = fsub double %value_phi38, %value_phi38
  %210 = fcmp ord double %209, 0.000000e+00
  %211 = fcmp ole double %206, %value_phi38
  %212 = and i1 %210, %211
  %213 = and i1 %208, %212
  br i1 %213, label %L144, label %L320
}
