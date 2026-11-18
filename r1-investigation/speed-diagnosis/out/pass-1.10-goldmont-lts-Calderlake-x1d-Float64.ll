; Function Attrs: noinline
define double @julia_pass_1068({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe491 = alloca [3 x {}*], align 16
  %gcframe491.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe491, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe491 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %newstruct74 = alloca { [1 x [1 x i64]], i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe491 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe491, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe491.sub, {}*** %9, align 8
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
  %value_phi8 = phi double [ %266, %L293 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %267, %L293 ], [ 1, %L17 ]
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
  %32 = add nsw i64 %n.vec404, -8
  %33 = lshr exact i64 %32, 3
  %34 = add nuw nsw i64 %33, 1
  %xtraiter = and i64 %34, 1
  %35 = icmp eq i64 %32, 0
  br i1 %35, label %middle.block399.unr-lcssa, label %vector.ph402.new

vector.ph402.new:                                 ; preds = %vector.ph402
  %unroll_iter = and i64 %34, 4611686018427387902
  br label %vector.body407

vector.body407:                                   ; preds = %vector.body407, %vector.ph402.new
  %index408 = phi i64 [ 0, %vector.ph402.new ], [ %index.next419.1, %vector.body407 ]
  %vec.phi409 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402.new ], [ %68, %vector.body407 ]
  %vec.phi410 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402.new ], [ %69, %vector.body407 ]
  %vec.phi411 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402.new ], [ %72, %vector.body407 ]
  %vec.phi412 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402.new ], [ %73, %vector.body407 ]
  %vec.phi413 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402.new ], [ %76, %vector.body407 ]
  %vec.phi414 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402.new ], [ %77, %vector.body407 ]
  %niter = phi i64 [ 0, %vector.ph402.new ], [ %niter.next.1, %vector.body407 ]
  %36 = add i64 %29, %index408
  %37 = getelementptr inbounds double, double* %arrayptr27146, i64 %36
  %38 = bitcast double* %37 to <4 x double>*
  %wide.load415 = load <4 x double>, <4 x double>* %38, align 8
  %39 = getelementptr inbounds double, double* %37, i64 4
  %40 = bitcast double* %39 to <4 x double>*
  %wide.load416 = load <4 x double>, <4 x double>* %40, align 8
  %41 = getelementptr inbounds double, double* %arrayptr30147, i64 %index408
  %42 = bitcast double* %41 to <4 x double>*
  %wide.load417 = load <4 x double>, <4 x double>* %42, align 8
  %43 = getelementptr inbounds double, double* %41, i64 4
  %44 = bitcast double* %43 to <4 x double>*
  %wide.load418 = load <4 x double>, <4 x double>* %44, align 8
  %45 = fmul contract <4 x double> %wide.load415, %wide.load415
  %46 = fmul contract <4 x double> %wide.load416, %wide.load416
  %47 = fadd reassoc contract <4 x double> %vec.phi409, %45
  %48 = fadd reassoc contract <4 x double> %vec.phi410, %46
  %49 = fmul contract <4 x double> %wide.load415, %wide.load417
  %50 = fmul contract <4 x double> %wide.load416, %wide.load418
  %51 = fadd reassoc contract <4 x double> %vec.phi411, %49
  %52 = fadd reassoc contract <4 x double> %vec.phi412, %50
  %53 = fmul contract <4 x double> %wide.load417, %wide.load417
  %54 = fmul contract <4 x double> %wide.load418, %wide.load418
  %55 = fadd reassoc contract <4 x double> %vec.phi413, %53
  %56 = fadd reassoc contract <4 x double> %vec.phi414, %54
  %index.next419 = or i64 %index408, 8
  %57 = add i64 %29, %index.next419
  %58 = getelementptr inbounds double, double* %arrayptr27146, i64 %57
  %59 = bitcast double* %58 to <4 x double>*
  %wide.load415.1 = load <4 x double>, <4 x double>* %59, align 8
  %60 = getelementptr inbounds double, double* %58, i64 4
  %61 = bitcast double* %60 to <4 x double>*
  %wide.load416.1 = load <4 x double>, <4 x double>* %61, align 8
  %62 = getelementptr inbounds double, double* %arrayptr30147, i64 %index.next419
  %63 = bitcast double* %62 to <4 x double>*
  %wide.load417.1 = load <4 x double>, <4 x double>* %63, align 8
  %64 = getelementptr inbounds double, double* %62, i64 4
  %65 = bitcast double* %64 to <4 x double>*
  %wide.load418.1 = load <4 x double>, <4 x double>* %65, align 8
  %66 = fmul contract <4 x double> %wide.load415.1, %wide.load415.1
  %67 = fmul contract <4 x double> %wide.load416.1, %wide.load416.1
  %68 = fadd reassoc contract <4 x double> %47, %66
  %69 = fadd reassoc contract <4 x double> %48, %67
  %70 = fmul contract <4 x double> %wide.load415.1, %wide.load417.1
  %71 = fmul contract <4 x double> %wide.load416.1, %wide.load418.1
  %72 = fadd reassoc contract <4 x double> %51, %70
  %73 = fadd reassoc contract <4 x double> %52, %71
  %74 = fmul contract <4 x double> %wide.load417.1, %wide.load417.1
  %75 = fmul contract <4 x double> %wide.load418.1, %wide.load418.1
  %76 = fadd reassoc contract <4 x double> %55, %74
  %77 = fadd reassoc contract <4 x double> %56, %75
  %index.next419.1 = add nuw i64 %index408, 16
  %niter.next.1 = add i64 %niter, 2
  %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_iter
  br i1 %niter.ncmp.1, label %middle.block399.unr-lcssa, label %vector.body407

middle.block399.unr-lcssa:                        ; preds = %vector.body407, %vector.ph402
  %.lcssa432.ph = phi <4 x double> [ undef, %vector.ph402 ], [ %68, %vector.body407 ]
  %.lcssa431.ph = phi <4 x double> [ undef, %vector.ph402 ], [ %69, %vector.body407 ]
  %.lcssa430.ph = phi <4 x double> [ undef, %vector.ph402 ], [ %72, %vector.body407 ]
  %.lcssa429.ph = phi <4 x double> [ undef, %vector.ph402 ], [ %73, %vector.body407 ]
  %.lcssa428.ph = phi <4 x double> [ undef, %vector.ph402 ], [ %76, %vector.body407 ]
  %.lcssa.ph = phi <4 x double> [ undef, %vector.ph402 ], [ %77, %vector.body407 ]
  %index408.unr = phi i64 [ 0, %vector.ph402 ], [ %index.next419.1, %vector.body407 ]
  %vec.phi409.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %68, %vector.body407 ]
  %vec.phi410.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %69, %vector.body407 ]
  %vec.phi411.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %72, %vector.body407 ]
  %vec.phi412.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %73, %vector.body407 ]
  %vec.phi413.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %76, %vector.body407 ]
  %vec.phi414.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph402 ], [ %77, %vector.body407 ]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %middle.block399, label %vector.body407.epil.preheader

vector.body407.epil.preheader:                    ; preds = %middle.block399.unr-lcssa
  %78 = add i64 %29, %index408.unr
  %79 = getelementptr inbounds double, double* %arrayptr27146, i64 %78
  %80 = bitcast double* %79 to <4 x double>*
  %wide.load415.epil = load <4 x double>, <4 x double>* %80, align 8
  %81 = getelementptr inbounds double, double* %79, i64 4
  %82 = bitcast double* %81 to <4 x double>*
  %wide.load416.epil = load <4 x double>, <4 x double>* %82, align 8
  %83 = getelementptr inbounds double, double* %arrayptr30147, i64 %index408.unr
  %84 = bitcast double* %83 to <4 x double>*
  %wide.load417.epil = load <4 x double>, <4 x double>* %84, align 8
  %85 = getelementptr inbounds double, double* %83, i64 4
  %86 = bitcast double* %85 to <4 x double>*
  %wide.load418.epil = load <4 x double>, <4 x double>* %86, align 8
  %87 = fmul contract <4 x double> %wide.load415.epil, %wide.load415.epil
  %88 = fmul contract <4 x double> %wide.load416.epil, %wide.load416.epil
  %89 = fadd reassoc contract <4 x double> %vec.phi409.unr, %87
  %90 = fadd reassoc contract <4 x double> %vec.phi410.unr, %88
  %91 = fmul contract <4 x double> %wide.load415.epil, %wide.load417.epil
  %92 = fmul contract <4 x double> %wide.load416.epil, %wide.load418.epil
  %93 = fadd reassoc contract <4 x double> %vec.phi411.unr, %91
  %94 = fadd reassoc contract <4 x double> %vec.phi412.unr, %92
  %95 = fmul contract <4 x double> %wide.load417.epil, %wide.load417.epil
  %96 = fmul contract <4 x double> %wide.load418.epil, %wide.load418.epil
  %97 = fadd reassoc contract <4 x double> %vec.phi413.unr, %95
  %98 = fadd reassoc contract <4 x double> %vec.phi414.unr, %96
  br label %middle.block399

middle.block399:                                  ; preds = %vector.body407.epil.preheader, %middle.block399.unr-lcssa
  %.lcssa432 = phi <4 x double> [ %.lcssa432.ph, %middle.block399.unr-lcssa ], [ %89, %vector.body407.epil.preheader ]
  %.lcssa431 = phi <4 x double> [ %.lcssa431.ph, %middle.block399.unr-lcssa ], [ %90, %vector.body407.epil.preheader ]
  %.lcssa430 = phi <4 x double> [ %.lcssa430.ph, %middle.block399.unr-lcssa ], [ %93, %vector.body407.epil.preheader ]
  %.lcssa429 = phi <4 x double> [ %.lcssa429.ph, %middle.block399.unr-lcssa ], [ %94, %vector.body407.epil.preheader ]
  %.lcssa428 = phi <4 x double> [ %.lcssa428.ph, %middle.block399.unr-lcssa ], [ %97, %vector.body407.epil.preheader ]
  %.lcssa = phi <4 x double> [ %.lcssa.ph, %middle.block399.unr-lcssa ], [ %98, %vector.body407.epil.preheader ]
  %bin.rdx424 = fadd reassoc contract <4 x double> %.lcssa, %.lcssa428
  %99 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx424)
  %bin.rdx422 = fadd reassoc contract <4 x double> %.lcssa429, %.lcssa430
  %100 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx422)
  %bin.rdx420 = fadd reassoc contract <4 x double> %.lcssa431, %.lcssa432
  %101 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx420)
  %cmp.n406 = icmp eq i64 %arraylen116, %n.vec404
  br i1 %cmp.n406, label %L124, label %scalar.ph400

scalar.ph400:                                     ; preds = %middle.block399, %L54.lr.ph
  %bc.resume.val405 = phi i64 [ %n.vec404, %middle.block399 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx421 = phi double [ %101, %middle.block399 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx423 = phi double [ %100, %middle.block399 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx425 = phi double [ %99, %middle.block399 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph400
  %value_phi25195 = phi double [ %bc.merge.rdx421, %scalar.ph400 ], [ %106, %L54 ]
  %value_phi24194 = phi i64 [ %bc.resume.val405, %scalar.ph400 ], [ %111, %L54 ]
  %value_phi23193 = phi double [ %bc.merge.rdx423, %scalar.ph400 ], [ %108, %L54 ]
  %value_phi22192 = phi double [ %bc.merge.rdx425, %scalar.ph400 ], [ %110, %L54 ]
  %102 = add i64 %29, %value_phi24194
  %103 = getelementptr inbounds double, double* %arrayptr27146, i64 %102
  %arrayref28 = load double, double* %103, align 8
  %104 = getelementptr inbounds double, double* %arrayptr30147, i64 %value_phi24194
  %arrayref31 = load double, double* %104, align 8
  %105 = fmul contract double %arrayref28, %arrayref28
  %106 = fadd reassoc contract double %value_phi25195, %105
  %107 = fmul contract double %arrayref28, %arrayref31
  %108 = fadd reassoc contract double %value_phi23193, %107
  %109 = fmul contract double %arrayref31, %arrayref31
  %110 = fadd reassoc contract double %value_phi22192, %109
  %111 = add nuw nsw i64 %value_phi24194, 1
  %exitcond.not = icmp eq i64 %111, %arraylen116
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not156, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %112 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr122 = getelementptr inbounds {}*, {}** %112, i64 3
  %113 = bitcast {}** %arraysize_ptr122 to i64*
  %arraysize123 = load i64, i64* %113, align 8
  %114 = mul i64 %arraysize123, %25
  %115 = bitcast {}* %getfield12 to double**
  %arrayptr126158 = load double*, double** %115, align 8
  %116 = bitcast {}* %getfield14 to double**
  %arrayptr129159 = load double*, double** %116, align 8
  %min.iters.check378 = icmp ult i64 %arraylen116, 8
  br i1 %min.iters.check378, label %scalar.ph377, label %vector.ph379

vector.ph379:                                     ; preds = %L96.lr.ph
  %n.vec381 = and i64 %arraylen116, 9223372036854775800
  %117 = add nsw i64 %n.vec381, -8
  %118 = lshr exact i64 %117, 3
  %119 = add nuw nsw i64 %118, 1
  %xtraiter482 = and i64 %119, 1
  %120 = icmp eq i64 %117, 0
  br i1 %120, label %middle.block376.unr-lcssa, label %vector.ph379.new

vector.ph379.new:                                 ; preds = %vector.ph379
  %unroll_iter488 = and i64 %119, 4611686018427387902
  br label %vector.body384

vector.body384:                                   ; preds = %vector.body384, %vector.ph379.new
  %index385 = phi i64 [ 0, %vector.ph379.new ], [ %index.next394.1, %vector.body384 ]
  %vec.phi386 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379.new ], [ %149, %vector.body384 ]
  %vec.phi387 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379.new ], [ %150, %vector.body384 ]
  %vec.phi388 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379.new ], [ %153, %vector.body384 ]
  %vec.phi389 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379.new ], [ %154, %vector.body384 ]
  %niter489 = phi i64 [ 0, %vector.ph379.new ], [ %niter489.next.1, %vector.body384 ]
  %121 = add i64 %114, %index385
  %122 = getelementptr inbounds double, double* %arrayptr126158, i64 %121
  %123 = bitcast double* %122 to <4 x double>*
  %wide.load390 = load <4 x double>, <4 x double>* %123, align 8
  %124 = getelementptr inbounds double, double* %122, i64 4
  %125 = bitcast double* %124 to <4 x double>*
  %wide.load391 = load <4 x double>, <4 x double>* %125, align 8
  %126 = getelementptr inbounds double, double* %arrayptr129159, i64 %index385
  %127 = bitcast double* %126 to <4 x double>*
  %wide.load392 = load <4 x double>, <4 x double>* %127, align 8
  %128 = getelementptr inbounds double, double* %126, i64 4
  %129 = bitcast double* %128 to <4 x double>*
  %wide.load393 = load <4 x double>, <4 x double>* %129, align 8
  %130 = fmul contract <4 x double> %wide.load390, %wide.load392
  %131 = fmul contract <4 x double> %wide.load391, %wide.load393
  %132 = fadd reassoc contract <4 x double> %vec.phi386, %130
  %133 = fadd reassoc contract <4 x double> %vec.phi387, %131
  %134 = fmul contract <4 x double> %wide.load392, %wide.load392
  %135 = fmul contract <4 x double> %wide.load393, %wide.load393
  %136 = fadd reassoc contract <4 x double> %vec.phi388, %134
  %137 = fadd reassoc contract <4 x double> %vec.phi389, %135
  %index.next394 = or i64 %index385, 8
  %138 = add i64 %114, %index.next394
  %139 = getelementptr inbounds double, double* %arrayptr126158, i64 %138
  %140 = bitcast double* %139 to <4 x double>*
  %wide.load390.1 = load <4 x double>, <4 x double>* %140, align 8
  %141 = getelementptr inbounds double, double* %139, i64 4
  %142 = bitcast double* %141 to <4 x double>*
  %wide.load391.1 = load <4 x double>, <4 x double>* %142, align 8
  %143 = getelementptr inbounds double, double* %arrayptr129159, i64 %index.next394
  %144 = bitcast double* %143 to <4 x double>*
  %wide.load392.1 = load <4 x double>, <4 x double>* %144, align 8
  %145 = getelementptr inbounds double, double* %143, i64 4
  %146 = bitcast double* %145 to <4 x double>*
  %wide.load393.1 = load <4 x double>, <4 x double>* %146, align 8
  %147 = fmul contract <4 x double> %wide.load390.1, %wide.load392.1
  %148 = fmul contract <4 x double> %wide.load391.1, %wide.load393.1
  %149 = fadd reassoc contract <4 x double> %132, %147
  %150 = fadd reassoc contract <4 x double> %133, %148
  %151 = fmul contract <4 x double> %wide.load392.1, %wide.load392.1
  %152 = fmul contract <4 x double> %wide.load393.1, %wide.load393.1
  %153 = fadd reassoc contract <4 x double> %136, %151
  %154 = fadd reassoc contract <4 x double> %137, %152
  %index.next394.1 = add nuw i64 %index385, 16
  %niter489.next.1 = add i64 %niter489, 2
  %niter489.ncmp.1 = icmp eq i64 %niter489.next.1, %unroll_iter488
  br i1 %niter489.ncmp.1, label %middle.block376.unr-lcssa, label %vector.body384

middle.block376.unr-lcssa:                        ; preds = %vector.body384, %vector.ph379
  %.lcssa439.ph = phi <4 x double> [ undef, %vector.ph379 ], [ %149, %vector.body384 ]
  %.lcssa438.ph = phi <4 x double> [ undef, %vector.ph379 ], [ %150, %vector.body384 ]
  %.lcssa437.ph = phi <4 x double> [ undef, %vector.ph379 ], [ %153, %vector.body384 ]
  %.lcssa436.ph = phi <4 x double> [ undef, %vector.ph379 ], [ %154, %vector.body384 ]
  %index385.unr = phi i64 [ 0, %vector.ph379 ], [ %index.next394.1, %vector.body384 ]
  %vec.phi386.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %149, %vector.body384 ]
  %vec.phi387.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %150, %vector.body384 ]
  %vec.phi388.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %153, %vector.body384 ]
  %vec.phi389.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph379 ], [ %154, %vector.body384 ]
  %lcmp.mod483.not = icmp eq i64 %xtraiter482, 0
  br i1 %lcmp.mod483.not, label %middle.block376, label %vector.body384.epil.preheader

vector.body384.epil.preheader:                    ; preds = %middle.block376.unr-lcssa
  %155 = add i64 %114, %index385.unr
  %156 = getelementptr inbounds double, double* %arrayptr126158, i64 %155
  %157 = bitcast double* %156 to <4 x double>*
  %wide.load390.epil = load <4 x double>, <4 x double>* %157, align 8
  %158 = getelementptr inbounds double, double* %156, i64 4
  %159 = bitcast double* %158 to <4 x double>*
  %wide.load391.epil = load <4 x double>, <4 x double>* %159, align 8
  %160 = getelementptr inbounds double, double* %arrayptr129159, i64 %index385.unr
  %161 = bitcast double* %160 to <4 x double>*
  %wide.load392.epil = load <4 x double>, <4 x double>* %161, align 8
  %162 = getelementptr inbounds double, double* %160, i64 4
  %163 = bitcast double* %162 to <4 x double>*
  %wide.load393.epil = load <4 x double>, <4 x double>* %163, align 8
  %164 = fmul contract <4 x double> %wide.load390.epil, %wide.load392.epil
  %165 = fmul contract <4 x double> %wide.load391.epil, %wide.load393.epil
  %166 = fadd reassoc contract <4 x double> %vec.phi386.unr, %164
  %167 = fadd reassoc contract <4 x double> %vec.phi387.unr, %165
  %168 = fmul contract <4 x double> %wide.load392.epil, %wide.load392.epil
  %169 = fmul contract <4 x double> %wide.load393.epil, %wide.load393.epil
  %170 = fadd reassoc contract <4 x double> %vec.phi388.unr, %168
  %171 = fadd reassoc contract <4 x double> %vec.phi389.unr, %169
  br label %middle.block376

middle.block376:                                  ; preds = %vector.body384.epil.preheader, %middle.block376.unr-lcssa
  %.lcssa439 = phi <4 x double> [ %.lcssa439.ph, %middle.block376.unr-lcssa ], [ %166, %vector.body384.epil.preheader ]
  %.lcssa438 = phi <4 x double> [ %.lcssa438.ph, %middle.block376.unr-lcssa ], [ %167, %vector.body384.epil.preheader ]
  %.lcssa437 = phi <4 x double> [ %.lcssa437.ph, %middle.block376.unr-lcssa ], [ %170, %vector.body384.epil.preheader ]
  %.lcssa436 = phi <4 x double> [ %.lcssa436.ph, %middle.block376.unr-lcssa ], [ %171, %vector.body384.epil.preheader ]
  %bin.rdx397 = fadd reassoc contract <4 x double> %.lcssa436, %.lcssa437
  %172 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx397)
  %bin.rdx395 = fadd reassoc contract <4 x double> %.lcssa438, %.lcssa439
  %173 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx395)
  %cmp.n383 = icmp eq i64 %arraylen116, %n.vec381
  br i1 %cmp.n383, label %L124, label %scalar.ph377

scalar.ph377:                                     ; preds = %middle.block376, %L96.lr.ph
  %bc.resume.val382 = phi i64 [ %n.vec381, %middle.block376 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx396 = phi double [ %173, %middle.block376 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx398 = phi double [ %172, %middle.block376 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph377
  %value_phi121201 = phi i64 [ %bc.resume.val382, %scalar.ph377 ], [ %181, %L96 ]
  %value_phi120200 = phi double [ %bc.merge.rdx396, %scalar.ph377 ], [ %178, %L96 ]
  %value_phi119199 = phi double [ %bc.merge.rdx398, %scalar.ph377 ], [ %180, %L96 ]
  %174 = add i64 %114, %value_phi121201
  %175 = getelementptr inbounds double, double* %arrayptr126158, i64 %174
  %arrayref127 = load double, double* %175, align 8
  %176 = getelementptr inbounds double, double* %arrayptr129159, i64 %value_phi121201
  %arrayref130 = load double, double* %176, align 8
  %177 = fmul contract double %arrayref127, %arrayref130
  %178 = fadd reassoc contract double %value_phi120200, %177
  %179 = fmul contract double %arrayref130, %arrayref130
  %180 = fadd reassoc contract double %value_phi119199, %179
  %181 = add nuw nsw i64 %value_phi121201, 1
  %exitcond256.not = icmp eq i64 %181, %arraylen116
  br i1 %exitcond256.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block376, %L83, %L54, %middle.block399, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %172, %middle.block376 ], [ %99, %middle.block399 ], [ %180, %L96 ], [ %110, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %173, %middle.block376 ], [ %100, %middle.block399 ], [ %178, %L96 ], [ %108, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block376 ], [ %101, %middle.block399 ], [ %arrayref, %L96 ], [ %106, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %25, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L148:                                             ; preds = %idxend46
  %182 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %182, label %L152, label %L150

L150:                                             ; preds = %L148
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 140312453360144 to {}*), double %value_phi40) #3
  unreachable

L152:                                             ; preds = %L148
  %183 = call double @llvm.sqrt.f64(double %value_phi40)
  %184 = fcmp ugt double %183, %aggregate_load_box.sroa.0.0.copyload
  br i1 %184, label %L157, label %L293

L157:                                             ; preds = %L152
  %185 = fdiv double %value_phi39, %value_phi40
  %186 = fmul double %value_phi39, %185
  %187 = fsub double %value_phi38, %186
  %188 = fmul double %value_phi38, 6.250000e-02
  %189 = fcmp uge double %187, %188
  br i1 %189, label %L245, label %L163

L163:                                             ; preds = %L157
  %190 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr69 = getelementptr inbounds {}*, {}** %190, i64 3
  %191 = bitcast {}** %arraysize_ptr69 to i64*
  %arraysize70 = load i64, i64* %191, align 8
  %arraysize_ptr75 = getelementptr inbounds {}*, {}** %190, i64 4
  %192 = bitcast {}** %arraysize_ptr75 to i64*
  %arraysize76 = load i64, i64* %192, align 8
  %.not151 = icmp ult i64 %25, %arraysize76
  br i1 %.not151, label %L184, label %L181

L181:                                             ; preds = %L163
  store i64 %arraysize70, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %21, align 8
  %193 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe491, i64 0, i64 2
  store {}* %getfield53, {}** %193, align 16
  call void @j_throw_boundserror_1073({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct74) #3
  unreachable

L184:                                             ; preds = %L163
  %194 = mul i64 %arraysize70, %25
  %.not152 = icmp eq i64 %arraylen59, 0
  br i1 %.not152, label %L252, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L184
  %195 = bitcast {}* %getfield57 to double**
  %arrayptr92154 = load double*, double** %195, align 8
  %196 = bitcast {}* %getfield53 to double**
  %arrayptr96155 = load double*, double** %196, align 8
  %min.iters.check = icmp ult i64 %arraylen59, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen59, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %185, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %226, %vector.body ]
  %vec.phi358 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %227, %vector.body ]
  %vec.phi359 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %228, %vector.body ]
  %vec.phi360 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %229, %vector.body ]
  %197 = getelementptr inbounds double, double* %arrayptr92154, i64 %index
  %198 = bitcast double* %197 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %198, align 8
  %199 = getelementptr inbounds double, double* %197, i64 4
  %200 = bitcast double* %199 to <4 x double>*
  %wide.load361 = load <4 x double>, <4 x double>* %200, align 8
  %201 = getelementptr inbounds double, double* %197, i64 8
  %202 = bitcast double* %201 to <4 x double>*
  %wide.load362 = load <4 x double>, <4 x double>* %202, align 8
  %203 = getelementptr inbounds double, double* %197, i64 12
  %204 = bitcast double* %203 to <4 x double>*
  %wide.load363 = load <4 x double>, <4 x double>* %204, align 8
  %205 = add i64 %index, %194
  %206 = getelementptr inbounds double, double* %arrayptr96155, i64 %205
  %207 = bitcast double* %206 to <4 x double>*
  %wide.load364 = load <4 x double>, <4 x double>* %207, align 8
  %208 = getelementptr inbounds double, double* %206, i64 4
  %209 = bitcast double* %208 to <4 x double>*
  %wide.load365 = load <4 x double>, <4 x double>* %209, align 8
  %210 = getelementptr inbounds double, double* %206, i64 8
  %211 = bitcast double* %210 to <4 x double>*
  %wide.load366 = load <4 x double>, <4 x double>* %211, align 8
  %212 = getelementptr inbounds double, double* %206, i64 12
  %213 = bitcast double* %212 to <4 x double>*
  %wide.load367 = load <4 x double>, <4 x double>* %213, align 8
  %214 = fmul <4 x double> %broadcast.splat, %wide.load364
  %215 = fmul <4 x double> %broadcast.splat, %wide.load365
  %216 = fmul <4 x double> %broadcast.splat, %wide.load366
  %217 = fmul <4 x double> %broadcast.splat, %wide.load367
  %218 = fsub <4 x double> %wide.load, %214
  %219 = fsub <4 x double> %wide.load361, %215
  %220 = fsub <4 x double> %wide.load362, %216
  %221 = fsub <4 x double> %wide.load363, %217
  %222 = fmul contract <4 x double> %218, %218
  %223 = fmul contract <4 x double> %219, %219
  %224 = fmul contract <4 x double> %220, %220
  %225 = fmul contract <4 x double> %221, %221
  %226 = fadd reassoc contract <4 x double> %vec.phi, %222
  %227 = fadd reassoc contract <4 x double> %vec.phi358, %223
  %228 = fadd reassoc contract <4 x double> %vec.phi359, %224
  %229 = fadd reassoc contract <4 x double> %vec.phi360, %225
  %index.next = add nuw i64 %index, 16
  %230 = icmp eq i64 %index.next, %n.vec
  br i1 %230, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %227, %226
  %bin.rdx374 = fadd reassoc contract <4 x double> %228, %bin.rdx
  %bin.rdx375 = fadd reassoc contract <4 x double> %229, %bin.rdx374
  %231 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx375)
  %cmp.n = icmp eq i64 %arraylen59, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi double [ %231, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90206 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %239, %L208 ]
  %value_phi89205 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %238, %L208 ]
  %232 = getelementptr inbounds double, double* %arrayptr92154, i64 %value_phi90206
  %arrayref93 = load double, double* %232, align 8
  %233 = add i64 %value_phi90206, %194
  %234 = getelementptr inbounds double, double* %arrayptr96155, i64 %233
  %arrayref97 = load double, double* %234, align 8
  %235 = fmul double %185, %arrayref97
  %236 = fsub double %arrayref93, %235
  %237 = fmul contract double %236, %236
  %238 = fadd reassoc contract double %value_phi89205, %237
  %239 = add nuw nsw i64 %value_phi90206, 1
  %exitcond257.not = icmp eq i64 %239, %arraylen59
  br i1 %exitcond257.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L157
  %value_phi9223 = phi i64 [ %value_phi9224, %L157 ], [ %value_phi9, %middle.block ], [ %value_phi9, %L208 ]
  %arraysize70210 = phi i64 [ %arraysize70211, %L157 ], [ %arraysize70, %middle.block ], [ %arraysize70, %L208 ]
  %value_phi102 = phi double [ %187, %L157 ], [ %231, %middle.block ], [ %238, %L208 ]
  %240 = fcmp uge double %value_phi102, 0.000000e+00
  br i1 %240, label %L252, label %L250

L250:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 140312453360144 to {}*), double %value_phi102) #3
  unreachable

L252:                                             ; preds = %L245, %L184
  %value_phi9222 = phi i64 [ %value_phi9223, %L245 ], [ %value_phi9, %L184 ]
  %arraysize70209 = phi i64 [ %arraysize70210, %L245 ], [ %arraysize70, %L184 ]
  %value_phi102161 = phi double [ %value_phi102, %L245 ], [ 0.000000e+00, %L184 ]
  %241 = fadd double %185, %arrayref49
  %242 = fdiv double %aggregate_load_box.sroa.0.0.copyload, %183
  %243 = call double @llvm.sqrt.f64(double %value_phi102161)
  %244 = fsub double %183, %aggregate_load_box.sroa.0.0.copyload
  %245 = fcmp uge double %244, 0.000000e+00
  br i1 %245, label %L259, label %L257

L257:                                             ; preds = %L252
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 140312453360144 to {}*), double %244) #3
  unreachable

L259:                                             ; preds = %L252
  %246 = fadd double %183, %aggregate_load_box.sroa.0.0.copyload
  %247 = fcmp uge double %246, 0.000000e+00
  br i1 %247, label %L266, label %L264

L264:                                             ; preds = %L259
  call void @j_throw_complex_domainerror_1071({}* inttoptr (i64 140312453360144 to {}*), double %246) #3
  unreachable

L266:                                             ; preds = %L259
  %248 = call double @llvm.sqrt.f64(double %244)
  %249 = call double @llvm.sqrt.f64(double %246)
  %250 = fmul double %248, %249
  %251 = fdiv double %243, %250
  %252 = fmul double %242, %251
  %253 = fsub double %241, %252
  %bitcast_coercion = bitcast double %253 to i64
  %254 = icmp sgt i64 %bitcast_coercion, -1
  %255 = select i1 %254, double %253, double 0.000000e+00
  %256 = fcmp ord double %253, 0.000000e+00
  %257 = select i1 %256, double %255, double %253
  %258 = fadd double %241, %252
  %bitcast_coercion111 = bitcast double %258 to i64
  %259 = icmp sgt i64 %bitcast_coercion111, -1
  %260 = fcmp ord double %258, 0.000000e+00
  %261 = and i1 %260, %259
  %262 = select i1 %261, double 0.000000e+00, double %258
  %263 = fadd double %257, %262
  br label %L293

L289:                                             ; preds = %idxend46
  %264 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe491, i64 0, i64 2
  store {}* %getfield, {}** %264, align 16
  %265 = call double @j__sqrt_cold_1074({}* nonnull %0, double %arrayref49, double %value_phi40, i64 signext %value_phi9)
  br label %L293

L293:                                             ; preds = %L289, %L266, %L152
  %value_phi9221 = phi i64 [ %value_phi9222, %L266 ], [ %value_phi9224, %L289 ], [ %value_phi9224, %L152 ]
  %arraysize70208 = phi i64 [ %arraysize70209, %L266 ], [ %arraysize70211, %L289 ], [ %arraysize70211, %L152 ]
  %value_phi61 = phi double [ %263, %L266 ], [ %265, %L289 ], [ 0.000000e+00, %L152 ]
  %266 = fadd double %value_phi8, %value_phi61
  %.not149.not = icmp eq i64 %value_phi9, %arraylen
  %267 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not149.not, label %L305, label %L31

L305:                                             ; preds = %L293, %L17
  %value_phi9221.lcssa246 = phi i64 [ %value_phi9221.lcssa247, %L17 ], [ %value_phi9221, %L293 ]
  %arraysize70208.lcssa237 = phi i64 [ %arraysize70208.lcssa238, %L17 ], [ %arraysize70208, %L293 ]
  %value_phi65 = phi double [ %value_phi4, %L17 ], [ %266, %L293 ]
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
  %268 = load {}*, {}** %6, align 8
  %269 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %268, {}** %269, align 8
  ret double %value_phi68

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %270 = bitcast {}* %getfield16 to double**
  %arrayptr144 = load double*, double** %270, align 8
  %271 = getelementptr inbounds double, double* %arrayptr144, i64 %25
  %arrayref = load double, double* %271, align 8
  %272 = fcmp ord double %arrayref, 0.000000e+00
  %273 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr115 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %273, i64 0, i32 1
  %arraylen116 = load i64, i64* %arraylen_ptr115, align 8
  %.not156 = icmp eq i64 %arraylen116, 0
  br i1 %272, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48148 = load double*, double** %18, align 8
  %274 = getelementptr inbounds double, double* %arrayptr48148, i64 %25
  %arrayref49 = load double, double* %274, align 8
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %275 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %275 unordered, align 8
  %276 = bitcast {}* %getfield51 to i8*
  %getfield_addr56 = getelementptr inbounds i8, i8* %276, i64 24
  %277 = bitcast i8* %getfield_addr56 to {}**
  %getfield57 = load atomic {}*, {}** %277 unordered, align 8
  %aggregate_load_box.sroa.0.0.copyload = load double, double* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %278 = bitcast {}* %getfield57 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr58 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %278, i64 0, i32 1
  %arraylen59 = load i64, i64* %arraylen_ptr58, align 8
  %279 = fsub double %value_phi40, %value_phi40
  %280 = fcmp ord double %279, 0.000000e+00
  %281 = sitofp i64 %arraylen59 to double
  %282 = fmul double %281, 0x350000000000000
  %283 = fcmp ole double %282, %value_phi40
  %284 = and i1 %280, %283
  %285 = fsub double %value_phi38, %value_phi38
  %286 = fcmp ord double %285, 0.000000e+00
  %287 = fcmp ole double %282, %value_phi38
  %288 = and i1 %286, %287
  %289 = and i1 %284, %288
  br i1 %289, label %L148, label %L289
}
