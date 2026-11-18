; Function Attrs: noinline
define double @julia_pass_722({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe373 = alloca [3 x {}*], align 16
  %gcframe373.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe373, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe373 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe373 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe373, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe373.sub, {}*** %9, align 8
  %10 = bitcast {}* %0 to {}**
  %11 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %12 = icmp slt i64 %2, 1
  br i1 %12, label %L350, label %L17.preheader

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
  br i1 %22, label %L350, label %L17

L17thread-pre-split:                              ; preds = %L339
  %23 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %21, %L17.preheader ]
  %value_phi3 = phi i64 [ %23, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi double [ %value_phi61, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L339, label %L31

L31:                                              ; preds = %L326, %L17
  %value_phi8 = phi double [ %213, %L326 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %214, %L326 ], [ 1, %L17 ]
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
  br i1 %.not156, label %L124, label %L54.lr.ph

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
  %min.iters.check303 = icmp ult i64 %arraylen115, 8
  br i1 %min.iters.check303, label %scalar.ph302, label %vector.ph304

vector.ph304:                                     ; preds = %L54.lr.ph
  %n.vec306 = and i64 %arraylen115, 9223372036854775800
  br label %vector.body309

vector.body309:                                   ; preds = %vector.body309, %vector.ph304
  %index310 = phi i64 [ 0, %vector.ph304 ], [ %index.next321, %vector.body309 ]
  %vec.phi311 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph304 ], [ %42, %vector.body309 ]
  %vec.phi312 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph304 ], [ %43, %vector.body309 ]
  %vec.phi313 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph304 ], [ %46, %vector.body309 ]
  %vec.phi314 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph304 ], [ %47, %vector.body309 ]
  %vec.phi315 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph304 ], [ %50, %vector.body309 ]
  %vec.phi316 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph304 ], [ %51, %vector.body309 ]
  %31 = add i64 %28, %index310
  %32 = getelementptr inbounds double, double* %arrayptr27145, i64 %31
  %33 = bitcast double* %32 to <4 x double>*
  %wide.load317 = load <4 x double>, <4 x double>* %33, align 8
  %34 = getelementptr inbounds double, double* %32, i64 4
  %35 = bitcast double* %34 to <4 x double>*
  %wide.load318 = load <4 x double>, <4 x double>* %35, align 8
  %36 = getelementptr inbounds double, double* %arrayptr30146, i64 %index310
  %37 = bitcast double* %36 to <4 x double>*
  %wide.load319 = load <4 x double>, <4 x double>* %37, align 8
  %38 = getelementptr inbounds double, double* %36, i64 4
  %39 = bitcast double* %38 to <4 x double>*
  %wide.load320 = load <4 x double>, <4 x double>* %39, align 8
  %40 = fmul contract <4 x double> %wide.load317, %wide.load317
  %41 = fmul contract <4 x double> %wide.load318, %wide.load318
  %42 = fadd reassoc contract <4 x double> %vec.phi311, %40
  %43 = fadd reassoc contract <4 x double> %vec.phi312, %41
  %44 = fmul contract <4 x double> %wide.load317, %wide.load319
  %45 = fmul contract <4 x double> %wide.load318, %wide.load320
  %46 = fadd reassoc contract <4 x double> %vec.phi313, %44
  %47 = fadd reassoc contract <4 x double> %vec.phi314, %45
  %48 = fmul contract <4 x double> %wide.load319, %wide.load319
  %49 = fmul contract <4 x double> %wide.load320, %wide.load320
  %50 = fadd reassoc contract <4 x double> %vec.phi315, %48
  %51 = fadd reassoc contract <4 x double> %vec.phi316, %49
  %index.next321 = add nuw i64 %index310, 8
  %52 = icmp eq i64 %index.next321, %n.vec306
  br i1 %52, label %middle.block301, label %vector.body309

middle.block301:                                  ; preds = %vector.body309
  %bin.rdx326 = fadd reassoc contract <4 x double> %51, %50
  %53 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx326)
  %bin.rdx324 = fadd reassoc contract <4 x double> %47, %46
  %54 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx324)
  %bin.rdx322 = fadd reassoc contract <4 x double> %43, %42
  %55 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx322)
  %cmp.n308 = icmp eq i64 %arraylen115, %n.vec306
  br i1 %cmp.n308, label %L124, label %scalar.ph302

scalar.ph302:                                     ; preds = %middle.block301, %L54.lr.ph
  %bc.resume.val307 = phi i64 [ %n.vec306, %middle.block301 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx323 = phi double [ %55, %middle.block301 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx325 = phi double [ %54, %middle.block301 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx327 = phi double [ %53, %middle.block301 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph302
  %value_phi25187 = phi double [ %bc.merge.rdx323, %scalar.ph302 ], [ %60, %L54 ]
  %value_phi24186 = phi i64 [ %bc.resume.val307, %scalar.ph302 ], [ %65, %L54 ]
  %value_phi23185 = phi double [ %bc.merge.rdx325, %scalar.ph302 ], [ %62, %L54 ]
  %value_phi22184 = phi double [ %bc.merge.rdx327, %scalar.ph302 ], [ %64, %L54 ]
  %56 = add i64 %28, %value_phi24186
  %57 = getelementptr inbounds double, double* %arrayptr27145, i64 %56
  %arrayref28 = load double, double* %57, align 8
  %58 = getelementptr inbounds double, double* %arrayptr30146, i64 %value_phi24186
  %arrayref31 = load double, double* %58, align 8
  %59 = fmul contract double %arrayref28, %arrayref28
  %60 = fadd reassoc contract double %value_phi25187, %59
  %61 = fmul contract double %arrayref28, %arrayref31
  %62 = fadd reassoc contract double %value_phi23185, %61
  %63 = fmul contract double %arrayref31, %arrayref31
  %64 = fadd reassoc contract double %value_phi22184, %63
  %65 = add nuw nsw i64 %value_phi24186, 1
  %exitcond.not = icmp eq i64 %65, %arraylen115
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not156, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %66 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr121 = getelementptr inbounds {}*, {}** %66, i64 3
  %67 = bitcast {}** %arraysize_ptr121 to i64*
  %arraysize122 = load i64, i64* %67, align 8
  %68 = mul i64 %arraysize122, %24
  %69 = bitcast {}* %getfield12 to double**
  %arrayptr125158 = load double*, double** %69, align 8
  %70 = bitcast {}* %getfield14 to double**
  %arrayptr128159 = load double*, double** %70, align 8
  %min.iters.check280 = icmp ult i64 %arraylen115, 8
  br i1 %min.iters.check280, label %scalar.ph279, label %vector.ph281

vector.ph281:                                     ; preds = %L96.lr.ph
  %n.vec283 = and i64 %arraylen115, 9223372036854775800
  br label %vector.body286

vector.body286:                                   ; preds = %vector.body286, %vector.ph281
  %index287 = phi i64 [ 0, %vector.ph281 ], [ %index.next296, %vector.body286 ]
  %vec.phi288 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph281 ], [ %82, %vector.body286 ]
  %vec.phi289 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph281 ], [ %83, %vector.body286 ]
  %vec.phi290 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph281 ], [ %86, %vector.body286 ]
  %vec.phi291 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph281 ], [ %87, %vector.body286 ]
  %71 = add i64 %68, %index287
  %72 = getelementptr inbounds double, double* %arrayptr125158, i64 %71
  %73 = bitcast double* %72 to <4 x double>*
  %wide.load292 = load <4 x double>, <4 x double>* %73, align 8
  %74 = getelementptr inbounds double, double* %72, i64 4
  %75 = bitcast double* %74 to <4 x double>*
  %wide.load293 = load <4 x double>, <4 x double>* %75, align 8
  %76 = getelementptr inbounds double, double* %arrayptr128159, i64 %index287
  %77 = bitcast double* %76 to <4 x double>*
  %wide.load294 = load <4 x double>, <4 x double>* %77, align 8
  %78 = getelementptr inbounds double, double* %76, i64 4
  %79 = bitcast double* %78 to <4 x double>*
  %wide.load295 = load <4 x double>, <4 x double>* %79, align 8
  %80 = fmul contract <4 x double> %wide.load292, %wide.load294
  %81 = fmul contract <4 x double> %wide.load293, %wide.load295
  %82 = fadd reassoc contract <4 x double> %vec.phi288, %80
  %83 = fadd reassoc contract <4 x double> %vec.phi289, %81
  %84 = fmul contract <4 x double> %wide.load294, %wide.load294
  %85 = fmul contract <4 x double> %wide.load295, %wide.load295
  %86 = fadd reassoc contract <4 x double> %vec.phi290, %84
  %87 = fadd reassoc contract <4 x double> %vec.phi291, %85
  %index.next296 = add nuw i64 %index287, 8
  %88 = icmp eq i64 %index.next296, %n.vec283
  br i1 %88, label %middle.block278, label %vector.body286

middle.block278:                                  ; preds = %vector.body286
  %bin.rdx299 = fadd reassoc contract <4 x double> %87, %86
  %89 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx299)
  %bin.rdx297 = fadd reassoc contract <4 x double> %83, %82
  %90 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx297)
  %cmp.n285 = icmp eq i64 %arraylen115, %n.vec283
  br i1 %cmp.n285, label %L124, label %scalar.ph279

scalar.ph279:                                     ; preds = %middle.block278, %L96.lr.ph
  %bc.resume.val284 = phi i64 [ %n.vec283, %middle.block278 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx298 = phi double [ %90, %middle.block278 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx300 = phi double [ %89, %middle.block278 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph279
  %value_phi120193 = phi i64 [ %bc.resume.val284, %scalar.ph279 ], [ %98, %L96 ]
  %value_phi119192 = phi double [ %bc.merge.rdx298, %scalar.ph279 ], [ %95, %L96 ]
  %value_phi118191 = phi double [ %bc.merge.rdx300, %scalar.ph279 ], [ %97, %L96 ]
  %91 = add i64 %68, %value_phi120193
  %92 = getelementptr inbounds double, double* %arrayptr125158, i64 %91
  %arrayref126 = load double, double* %92, align 8
  %93 = getelementptr inbounds double, double* %arrayptr128159, i64 %value_phi120193
  %arrayref129 = load double, double* %93, align 8
  %94 = fmul contract double %arrayref126, %arrayref129
  %95 = fadd reassoc contract double %value_phi119192, %94
  %96 = fmul contract double %arrayref129, %arrayref129
  %97 = fadd reassoc contract double %value_phi118191, %96
  %98 = add nuw nsw i64 %value_phi120193, 1
  %exitcond200.not = icmp eq i64 %98, %arraylen115
  br i1 %exitcond200.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block278, %L83, %L54, %middle.block301, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %89, %middle.block278 ], [ %53, %middle.block301 ], [ %97, %L96 ], [ %64, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %90, %middle.block278 ], [ %54, %middle.block301 ], [ %95, %L96 ], [ %62, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block278 ], [ %55, %middle.block301 ], [ %arrayref, %L96 ], [ %60, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %24, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L144:                                             ; preds = %idxend46
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %99 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %99, label %L150, label %L148

L148:                                             ; preds = %L144
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 123609136802320 to {}*), double %value_phi40) #3
  unreachable

L150:                                             ; preds = %L144
  %100 = call double @llvm.sqrt.f64(double %value_phi40)
  %101 = fcmp ugt double %100, %aggregate_load_box.sroa.0.0.copyload
  br i1 %101, label %L155, label %L326

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
  %vec.phi260 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %144, %vector.body ]
  %vec.phi261 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %145, %vector.body ]
  %vec.phi262 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %146, %vector.body ]
  %114 = getelementptr inbounds double, double* %arrayptr76152, i64 %index
  %115 = bitcast double* %114 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %115, align 8
  %116 = getelementptr inbounds double, double* %114, i64 4
  %117 = bitcast double* %116 to <4 x double>*
  %wide.load263 = load <4 x double>, <4 x double>* %117, align 8
  %118 = getelementptr inbounds double, double* %114, i64 8
  %119 = bitcast double* %118 to <4 x double>*
  %wide.load264 = load <4 x double>, <4 x double>* %119, align 8
  %120 = getelementptr inbounds double, double* %114, i64 12
  %121 = bitcast double* %120 to <4 x double>*
  %wide.load265 = load <4 x double>, <4 x double>* %121, align 8
  %122 = add i64 %112, %index
  %123 = getelementptr inbounds double, double* %arrayptr82153, i64 %122
  %124 = bitcast double* %123 to <4 x double>*
  %wide.load266 = load <4 x double>, <4 x double>* %124, align 8
  %125 = getelementptr inbounds double, double* %123, i64 4
  %126 = bitcast double* %125 to <4 x double>*
  %wide.load267 = load <4 x double>, <4 x double>* %126, align 8
  %127 = getelementptr inbounds double, double* %123, i64 8
  %128 = bitcast double* %127 to <4 x double>*
  %wide.load268 = load <4 x double>, <4 x double>* %128, align 8
  %129 = getelementptr inbounds double, double* %123, i64 12
  %130 = bitcast double* %129 to <4 x double>*
  %wide.load269 = load <4 x double>, <4 x double>* %130, align 8
  %131 = fmul <4 x double> %broadcast.splat, %wide.load266
  %132 = fmul <4 x double> %broadcast.splat, %wide.load267
  %133 = fmul <4 x double> %broadcast.splat, %wide.load268
  %134 = fmul <4 x double> %broadcast.splat, %wide.load269
  %135 = fsub <4 x double> %wide.load, %131
  %136 = fsub <4 x double> %wide.load263, %132
  %137 = fsub <4 x double> %wide.load264, %133
  %138 = fsub <4 x double> %wide.load265, %134
  %139 = fmul contract <4 x double> %135, %135
  %140 = fmul contract <4 x double> %136, %136
  %141 = fmul contract <4 x double> %137, %137
  %142 = fmul contract <4 x double> %138, %138
  %143 = fadd reassoc contract <4 x double> %vec.phi, %139
  %144 = fadd reassoc contract <4 x double> %vec.phi260, %140
  %145 = fadd reassoc contract <4 x double> %vec.phi261, %141
  %146 = fadd reassoc contract <4 x double> %vec.phi262, %142
  %index.next = add nuw i64 %index, 16
  %147 = icmp eq i64 %index.next, %n.vec
  br i1 %147, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %144, %143
  %bin.rdx276 = fadd reassoc contract <4 x double> %145, %bin.rdx
  %bin.rdx277 = fadd reassoc contract <4 x double> %146, %bin.rdx276
  %148 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx277)
  %cmp.n = icmp eq i64 %arraylen55, %n.vec
  br i1 %cmp.n, label %L199, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L176.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L176.lr.ph ]
  %bc.merge.rdx = phi double [ %148, %middle.block ], [ 0.000000e+00, %L176.lr.ph ]
  br label %L176

L176:                                             ; preds = %L176, %scalar.ph
  %value_phi74198 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %156, %L176 ]
  %value_phi73197 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %155, %L176 ]
  %149 = getelementptr inbounds double, double* %arrayptr76152, i64 %value_phi74198
  %arrayref77 = load double, double* %149, align 8
  %150 = add i64 %112, %value_phi74198
  %151 = getelementptr inbounds double, double* %arrayptr82153, i64 %150
  %arrayref83 = load double, double* %151, align 8
  %152 = fmul double %102, %arrayref83
  %153 = fsub double %arrayref77, %152
  %154 = fmul contract double %153, %153
  %155 = fadd reassoc contract double %value_phi73197, %154
  %156 = add nuw nsw i64 %value_phi74198, 1
  %exitcond201.not = icmp eq i64 %156, %arraylen55
  br i1 %exitcond201.not, label %L199, label %L176

L199:                                             ; preds = %L176, %middle.block, %L162
  %value_phi85 = phi double [ 0.000000e+00, %L162 ], [ %148, %middle.block ], [ %155, %L176 ]
  %157 = fsub double %value_phi85, %value_phi85
  %158 = fcmp uno double %157, 0.000000e+00
  %159 = fcmp ugt double %228, %value_phi85
  %160 = or i1 %159, %158
  br i1 %160, label %L208, label %L210

L208:                                             ; preds = %L199
  %161 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe373, i64 0, i64 2
  store {}* %getfield, {}** %161, align 16
  %162 = call double @j__sqrt_offrange_step_728({}* nonnull %0, double %arrayref49, i64 signext %value_phi9)
  br label %L326

L210:                                             ; preds = %L199, %L155
  %value_phi87 = phi double [ %105, %L155 ], [ %value_phi85, %L199 ]
  %163 = fcmp uge double %value_phi87, 0.000000e+00
  br i1 %163, label %L215, label %L213

L213:                                             ; preds = %L210
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 123609136802320 to {}*), double %value_phi87) #3
  unreachable

L215:                                             ; preds = %L210
  %164 = call double @llvm.sqrt.f64(double %value_phi87)
  %165 = fsub double %100, %aggregate_load_box.sroa.0.0.copyload
  %166 = fcmp uge double %165, 0.000000e+00
  br i1 %166, label %L222, label %L220

L220:                                             ; preds = %L215
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 123609136802320 to {}*), double %165) #3
  unreachable

L222:                                             ; preds = %L215
  %167 = fadd double %100, %aggregate_load_box.sroa.0.0.copyload
  %168 = fcmp uge double %167, 0.000000e+00
  br i1 %168, label %L229, label %L227

L227:                                             ; preds = %L222
  call void @j_throw_complex_domainerror_725({}* inttoptr (i64 123609136802320 to {}*), double %167) #3
  unreachable

L229:                                             ; preds = %L222
  %169 = call double @llvm.sqrt.f64(double %165)
  %170 = call double @llvm.sqrt.f64(double %167)
  %171 = fmul double %169, %170
  %172 = fmul double %100, %171
  %173 = fdiv double %164, %172
  %174 = fcmp une double %164, 0.000000e+00
  br i1 %174, label %L238, label %L229.L257_crit_edge

L229.L257_crit_edge:                              ; preds = %L229
  %.pre = fmul double %173, %aggregate_load_box.sroa.0.0.copyload
  br label %L257

L238:                                             ; preds = %L229
  %175 = fmul double %aggregate_load_box.sroa.0.0.copyload, %173
  %176 = fcmp oge double %172, 0x10000000000000
  %177 = fcmp oge double %173, 0x10000000000000
  %178 = fcmp ole double %173, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %177, %178
  %179 = and i1 %176, %narrow
  %180 = fcmp oge double %175, 0x10000000000000
  %181 = fcmp ole double %175, 0x7FEFFFFFFFFFFFFF
  %narrow155 = and i1 %180, %181
  %182 = and i1 %179, %narrow155
  br i1 %182, label %L257, label %L255

L255:                                             ; preds = %L238
  %183 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe373, i64 0, i64 2
  store {}* %getfield, {}** %183, align 16
  %184 = call double @j__sqrt_band_step_727(double %103, double %100, double %aggregate_load_box.sroa.0.0.copyload, double %164, i64 signext 0)
  br label %L326

L257:                                             ; preds = %L238, %L229.L257_crit_edge
  %.pre-phi = phi double [ %.pre, %L229.L257_crit_edge ], [ %175, %L238 ]
  %185 = fcmp ult double %.pre-phi, 0x10000000000000
  %186 = fcmp ugt double %.pre-phi, 0x7FEFFFFFFFFFFFFF
  %187 = or i1 %185, %186
  br i1 %187, label %L293, label %L269

L269:                                             ; preds = %L257
  %188 = fneg double %.pre-phi
  %.inv = fcmp ogt double %103, %188
  %189 = select i1 %.inv, double %103, double %188
  %.inv154 = fcmp olt double %189, %.pre-phi
  %190 = select i1 %.inv154, double %189, double %.pre-phi
  %191 = fsub double %103, %190
  %192 = fadd double %191, 0.000000e+00
  br label %L326

L293:                                             ; preds = %L257
  %193 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe373, i64 0, i64 2
  store {}* %getfield, {}** %193, align 16
  %194 = call double @j__exceptional_product_726(double %173, double %aggregate_load_box.sroa.0.0.copyload, double 1.000000e+00)
  %195 = fsub double %103, %194
  %bitcast_coercion = bitcast double %195 to i64
  %196 = icmp sgt i64 %bitcast_coercion, -1
  %197 = select i1 %196, double %195, double 0.000000e+00
  %198 = fcmp ord double %195, 0.000000e+00
  %199 = select i1 %198, double %197, double %195
  %200 = fadd double %103, %194
  %bitcast_coercion105 = bitcast double %200 to i64
  %201 = icmp sgt i64 %bitcast_coercion105, -1
  %202 = fcmp ord double %200, 0.000000e+00
  %203 = and i1 %202, %201
  %204 = select i1 %203, double 0.000000e+00, double %200
  %205 = fadd double %199, %204
  %206 = fcmp ult double %173, 0.000000e+00
  %207 = call double @llvm.fabs.f64(double %aggregate_load_box.sroa.0.0.copyload)
  %208 = bitcast double %207 to i64
  %209 = icmp ne i64 %208, 9218868437227405312
  %ifelse_cond109 = or i1 %206, %209
  %210 = select i1 %ifelse_cond109, double %205, double 0.000000e+00
  br label %L326

L324:                                             ; preds = %idxend46
  %211 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe373, i64 0, i64 2
  store {}* %getfield, {}** %211, align 16
  %212 = call double @j__sqrt_offrange_step_728({}* nonnull %0, double %arrayref49, i64 signext %value_phi9)
  br label %L326

L326:                                             ; preds = %L324, %L293, %L269, %L255, %L208, %L150
  %value_phi57 = phi double [ %162, %L208 ], [ %184, %L255 ], [ %212, %L324 ], [ 0.000000e+00, %L150 ], [ %192, %L269 ], [ %210, %L293 ]
  %213 = fadd double %value_phi8, %value_phi57
  %.not148.not = icmp eq i64 %value_phi9, %arraylen
  %214 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not148.not, label %L339, label %L31

L339:                                             ; preds = %L326, %L17
  %value_phi61 = phi double [ %value_phi4, %L17 ], [ %213, %L326 ]
  %.not149 = icmp eq i64 %value_phi3, %11
  br i1 %.not149, label %L350, label %L17thread-pre-split

L350:                                             ; preds = %L339, %L17.preheader, %top
  %value_phi64 = phi double [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi61, %L339 ]
  %215 = load {}*, {}** %6, align 8
  %216 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %215, {}** %216, align 8
  ret double %value_phi64

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %217 = bitcast {}* %getfield16 to double**
  %arrayptr143 = load double*, double** %217, align 8
  %218 = getelementptr inbounds double, double* %arrayptr143, i64 %24
  %arrayref = load double, double* %218, align 8
  %219 = fcmp ord double %arrayref, 0.000000e+00
  %220 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr114 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %220, i64 0, i32 1
  %arraylen115 = load i64, i64* %arraylen_ptr114, align 8
  %.not156 = icmp eq i64 %arraylen115, 0
  br i1 %219, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48147 = load double*, double** %18, align 8
  %221 = getelementptr inbounds double, double* %arrayptr48147, i64 %24
  %arrayref49 = load double, double* %221, align 8
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %222 = bitcast {}* %getfield51 to i8*
  %getfield_addr52 = getelementptr inbounds i8, i8* %222, i64 24
  %223 = bitcast i8* %getfield_addr52 to {}**
  %getfield53 = load atomic {}*, {}** %223 unordered, align 8
  %224 = bitcast {}* %getfield53 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr54 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %224, i64 0, i32 1
  %arraylen55 = load i64, i64* %arraylen_ptr54, align 8
  %225 = fsub double %value_phi40, %value_phi40
  %226 = fcmp ord double %225, 0.000000e+00
  %227 = sitofp i64 %arraylen55 to double
  %228 = fmul double %227, 0x350000000000000
  %229 = fcmp ole double %228, %value_phi40
  %230 = and i1 %226, %229
  %231 = fsub double %value_phi38, %value_phi38
  %232 = fcmp ord double %231, 0.000000e+00
  %233 = fcmp ole double %228, %value_phi38
  %234 = and i1 %232, %233
  %235 = and i1 %230, %234
  br i1 %235, label %L144, label %L324
}
