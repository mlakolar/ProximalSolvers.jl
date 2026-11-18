; Function Attrs: noinline
define double @julia_pass_1311({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe532 = alloca [6 x {}*], align 16
  %gcframe532.sub = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 0
  %3 = bitcast [6 x {}*]* %gcframe532 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 48, i1 true)
  %4 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 3
  %5 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 2
  %newstruct59 = alloca { [1 x [1 x i64]], i64 }, align 8
  %aggregate_load_box = alloca { double }, align 8
  %6 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %7 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [6 x {}*]* %gcframe532 to i64*
  store i64 16, i64* %9, align 16
  %10 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe532.sub, {}*** %13, align 8
  %14 = bitcast {}* %0 to {}**
  %15 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %16 = icmp slt i64 %2, 1
  br i1 %16, label %L383, label %L17.preheader

L17.preheader:                                    ; preds = %top
  %getfield = load atomic {}*, {}** %14 unordered, align 8
  %17 = bitcast {}* %1 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %17, i64 0, i32 1
  %18 = bitcast {}* %getfield to {}**
  %19 = bitcast {}* %getfield to i8*
  %getfield_addr13 = getelementptr inbounds i8, i8* %19, i64 24
  %20 = bitcast i8* %getfield_addr13 to {}**
  %getfield_addr15 = getelementptr inbounds i8, i8* %19, i64 32
  %21 = bitcast i8* %getfield_addr15 to {}**
  %22 = bitcast {}* %1 to double**
  %memcpy_refined_dst = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct59, i64 0, i32 0, i64 0, i64 0
  %23 = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct59, i64 0, i32 1
  %24 = bitcast {}* %0 to i8*
  %25 = getelementptr inbounds i8, i8* %24, i64 8
  %26 = bitcast i8* %25 to i64*
  %27 = bitcast { double }* %aggregate_load_box to i64*
  %.fca.0.gep = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %7, i64 0, i32 0
  %.fca.1.0.0.0.gep = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %7, i64 0, i32 1, i32 0, i64 0, i64 0
  %.fca.1.1.gep = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %7, i64 0, i32 1, i32 1
  %.fca.2.gep = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %7, i64 0, i32 2
  %.fca.3.gep = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %7, i64 0, i32 3
  %.fca.0.gep152 = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %6, i64 0, i32 0
  %.fca.1.0.0.0.gep154 = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %6, i64 0, i32 1, i32 0, i64 0, i64 0
  %.fca.1.1.gep156 = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %6, i64 0, i32 1, i32 1
  %.fca.2.gep158 = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %6, i64 0, i32 2
  %.fca.3.gep160 = getelementptr inbounds { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* %6, i64 0, i32 3
  %28 = load i64, i64* %arraylen_ptr, align 8
  %29 = icmp eq i64 %28, 0
  br i1 %29, label %L383.loopexit, label %L17

L17thread-pre-split:                              ; preds = %L372
  %30 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %28, %L17.preheader ]
  %value_phi9.lcssa263275 = phi i64 [ %value_phi9.lcssa263274, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %arraysize55.lcssa248266 = phi i64 [ %arraysize55.lcssa248265, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %value_phi3 = phi i64 [ %30, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi double [ %value_phi81, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L372, label %L31

L31:                                              ; preds = %L360, %L17
  %value_phi8 = phi double [ %313, %L360 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %314, %L360 ], [ 1, %L17 ]
  %getfield12 = load atomic {}*, {}** %18 unordered, align 8
  %getfield14 = load atomic {}*, {}** %20 unordered, align 8
  %getfield16 = load atomic {}*, {}** %21 unordered, align 8
  %31 = add nsw i64 %value_phi9, -1
  %32 = bitcast {}* %getfield16 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr17 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %32, i64 0, i32 1
  %arraylen18 = load i64, i64* %arraylen_ptr17, align 8
  %inbounds = icmp ult i64 %31, %arraylen18
  br i1 %inbounds, label %idxend, label %oob

L40:                                              ; preds = %idxend
  br i1 %.not184, label %L124, label %L54.lr.ph

L54.lr.ph:                                        ; preds = %L40
  %33 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr = getelementptr inbounds {}*, {}** %33, i64 3
  %34 = bitcast {}** %arraysize_ptr to i64*
  %arraysize = load i64, i64* %34, align 8
  %35 = mul i64 %arraysize, %31
  %36 = bitcast {}* %getfield12 to double**
  %arrayptr27170 = load double*, double** %36, align 8
  %37 = bitcast {}* %getfield14 to double**
  %arrayptr30171 = load double*, double** %37, align 8
  %min.iters.check437 = icmp ult i64 %arraylen129, 8
  br i1 %min.iters.check437, label %scalar.ph436, label %vector.ph438

vector.ph438:                                     ; preds = %L54.lr.ph
  %n.vec440 = and i64 %arraylen129, 9223372036854775800
  %38 = add nsw i64 %n.vec440, -8
  %39 = lshr exact i64 %38, 3
  %40 = add nuw nsw i64 %39, 1
  %xtraiter = and i64 %40, 1
  %41 = icmp eq i64 %38, 0
  br i1 %41, label %middle.block435.unr-lcssa, label %vector.ph438.new

vector.ph438.new:                                 ; preds = %vector.ph438
  %unroll_iter = and i64 %40, 4611686018427387902
  br label %vector.body443

vector.body443:                                   ; preds = %vector.body443, %vector.ph438.new
  %index444 = phi i64 [ 0, %vector.ph438.new ], [ %index.next455.1, %vector.body443 ]
  %vec.phi445 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438.new ], [ %74, %vector.body443 ]
  %vec.phi446 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438.new ], [ %75, %vector.body443 ]
  %vec.phi447 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438.new ], [ %78, %vector.body443 ]
  %vec.phi448 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438.new ], [ %79, %vector.body443 ]
  %vec.phi449 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438.new ], [ %82, %vector.body443 ]
  %vec.phi450 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438.new ], [ %83, %vector.body443 ]
  %niter = phi i64 [ 0, %vector.ph438.new ], [ %niter.next.1, %vector.body443 ]
  %42 = add i64 %35, %index444
  %43 = getelementptr inbounds double, double* %arrayptr27170, i64 %42
  %44 = bitcast double* %43 to <4 x double>*
  %wide.load451 = load <4 x double>, <4 x double>* %44, align 8
  %45 = getelementptr inbounds double, double* %43, i64 4
  %46 = bitcast double* %45 to <4 x double>*
  %wide.load452 = load <4 x double>, <4 x double>* %46, align 8
  %47 = getelementptr inbounds double, double* %arrayptr30171, i64 %index444
  %48 = bitcast double* %47 to <4 x double>*
  %wide.load453 = load <4 x double>, <4 x double>* %48, align 8
  %49 = getelementptr inbounds double, double* %47, i64 4
  %50 = bitcast double* %49 to <4 x double>*
  %wide.load454 = load <4 x double>, <4 x double>* %50, align 8
  %51 = fmul contract <4 x double> %wide.load451, %wide.load451
  %52 = fmul contract <4 x double> %wide.load452, %wide.load452
  %53 = fadd reassoc contract <4 x double> %vec.phi445, %51
  %54 = fadd reassoc contract <4 x double> %vec.phi446, %52
  %55 = fmul contract <4 x double> %wide.load451, %wide.load453
  %56 = fmul contract <4 x double> %wide.load452, %wide.load454
  %57 = fadd reassoc contract <4 x double> %vec.phi447, %55
  %58 = fadd reassoc contract <4 x double> %vec.phi448, %56
  %59 = fmul contract <4 x double> %wide.load453, %wide.load453
  %60 = fmul contract <4 x double> %wide.load454, %wide.load454
  %61 = fadd reassoc contract <4 x double> %vec.phi449, %59
  %62 = fadd reassoc contract <4 x double> %vec.phi450, %60
  %index.next455 = or i64 %index444, 8
  %63 = add i64 %35, %index.next455
  %64 = getelementptr inbounds double, double* %arrayptr27170, i64 %63
  %65 = bitcast double* %64 to <4 x double>*
  %wide.load451.1 = load <4 x double>, <4 x double>* %65, align 8
  %66 = getelementptr inbounds double, double* %64, i64 4
  %67 = bitcast double* %66 to <4 x double>*
  %wide.load452.1 = load <4 x double>, <4 x double>* %67, align 8
  %68 = getelementptr inbounds double, double* %arrayptr30171, i64 %index.next455
  %69 = bitcast double* %68 to <4 x double>*
  %wide.load453.1 = load <4 x double>, <4 x double>* %69, align 8
  %70 = getelementptr inbounds double, double* %68, i64 4
  %71 = bitcast double* %70 to <4 x double>*
  %wide.load454.1 = load <4 x double>, <4 x double>* %71, align 8
  %72 = fmul contract <4 x double> %wide.load451.1, %wide.load451.1
  %73 = fmul contract <4 x double> %wide.load452.1, %wide.load452.1
  %74 = fadd reassoc contract <4 x double> %53, %72
  %75 = fadd reassoc contract <4 x double> %54, %73
  %76 = fmul contract <4 x double> %wide.load451.1, %wide.load453.1
  %77 = fmul contract <4 x double> %wide.load452.1, %wide.load454.1
  %78 = fadd reassoc contract <4 x double> %57, %76
  %79 = fadd reassoc contract <4 x double> %58, %77
  %80 = fmul contract <4 x double> %wide.load453.1, %wide.load453.1
  %81 = fmul contract <4 x double> %wide.load454.1, %wide.load454.1
  %82 = fadd reassoc contract <4 x double> %61, %80
  %83 = fadd reassoc contract <4 x double> %62, %81
  %index.next455.1 = add nuw i64 %index444, 16
  %niter.next.1 = add i64 %niter, 2
  %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_iter
  br i1 %niter.ncmp.1, label %middle.block435.unr-lcssa, label %vector.body443

middle.block435.unr-lcssa:                        ; preds = %vector.body443, %vector.ph438
  %.lcssa468.ph = phi <4 x double> [ undef, %vector.ph438 ], [ %74, %vector.body443 ]
  %.lcssa467.ph = phi <4 x double> [ undef, %vector.ph438 ], [ %75, %vector.body443 ]
  %.lcssa466.ph = phi <4 x double> [ undef, %vector.ph438 ], [ %78, %vector.body443 ]
  %.lcssa465.ph = phi <4 x double> [ undef, %vector.ph438 ], [ %79, %vector.body443 ]
  %.lcssa464.ph = phi <4 x double> [ undef, %vector.ph438 ], [ %82, %vector.body443 ]
  %.lcssa.ph = phi <4 x double> [ undef, %vector.ph438 ], [ %83, %vector.body443 ]
  %index444.unr = phi i64 [ 0, %vector.ph438 ], [ %index.next455.1, %vector.body443 ]
  %vec.phi445.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %74, %vector.body443 ]
  %vec.phi446.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %75, %vector.body443 ]
  %vec.phi447.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %78, %vector.body443 ]
  %vec.phi448.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %79, %vector.body443 ]
  %vec.phi449.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %82, %vector.body443 ]
  %vec.phi450.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %83, %vector.body443 ]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %middle.block435, label %vector.body443.epil.preheader

vector.body443.epil.preheader:                    ; preds = %middle.block435.unr-lcssa
  %84 = add i64 %35, %index444.unr
  %85 = getelementptr inbounds double, double* %arrayptr27170, i64 %84
  %86 = bitcast double* %85 to <4 x double>*
  %wide.load451.epil = load <4 x double>, <4 x double>* %86, align 8
  %87 = getelementptr inbounds double, double* %85, i64 4
  %88 = bitcast double* %87 to <4 x double>*
  %wide.load452.epil = load <4 x double>, <4 x double>* %88, align 8
  %89 = getelementptr inbounds double, double* %arrayptr30171, i64 %index444.unr
  %90 = bitcast double* %89 to <4 x double>*
  %wide.load453.epil = load <4 x double>, <4 x double>* %90, align 8
  %91 = getelementptr inbounds double, double* %89, i64 4
  %92 = bitcast double* %91 to <4 x double>*
  %wide.load454.epil = load <4 x double>, <4 x double>* %92, align 8
  %93 = fmul contract <4 x double> %wide.load451.epil, %wide.load451.epil
  %94 = fmul contract <4 x double> %wide.load452.epil, %wide.load452.epil
  %95 = fadd reassoc contract <4 x double> %vec.phi445.unr, %93
  %96 = fadd reassoc contract <4 x double> %vec.phi446.unr, %94
  %97 = fmul contract <4 x double> %wide.load451.epil, %wide.load453.epil
  %98 = fmul contract <4 x double> %wide.load452.epil, %wide.load454.epil
  %99 = fadd reassoc contract <4 x double> %vec.phi447.unr, %97
  %100 = fadd reassoc contract <4 x double> %vec.phi448.unr, %98
  %101 = fmul contract <4 x double> %wide.load453.epil, %wide.load453.epil
  %102 = fmul contract <4 x double> %wide.load454.epil, %wide.load454.epil
  %103 = fadd reassoc contract <4 x double> %vec.phi449.unr, %101
  %104 = fadd reassoc contract <4 x double> %vec.phi450.unr, %102
  br label %middle.block435

middle.block435:                                  ; preds = %vector.body443.epil.preheader, %middle.block435.unr-lcssa
  %.lcssa468 = phi <4 x double> [ %.lcssa468.ph, %middle.block435.unr-lcssa ], [ %95, %vector.body443.epil.preheader ]
  %.lcssa467 = phi <4 x double> [ %.lcssa467.ph, %middle.block435.unr-lcssa ], [ %96, %vector.body443.epil.preheader ]
  %.lcssa466 = phi <4 x double> [ %.lcssa466.ph, %middle.block435.unr-lcssa ], [ %99, %vector.body443.epil.preheader ]
  %.lcssa465 = phi <4 x double> [ %.lcssa465.ph, %middle.block435.unr-lcssa ], [ %100, %vector.body443.epil.preheader ]
  %.lcssa464 = phi <4 x double> [ %.lcssa464.ph, %middle.block435.unr-lcssa ], [ %103, %vector.body443.epil.preheader ]
  %.lcssa = phi <4 x double> [ %.lcssa.ph, %middle.block435.unr-lcssa ], [ %104, %vector.body443.epil.preheader ]
  %bin.rdx460 = fadd reassoc contract <4 x double> %.lcssa, %.lcssa464
  %105 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx460)
  %bin.rdx458 = fadd reassoc contract <4 x double> %.lcssa465, %.lcssa466
  %106 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx458)
  %bin.rdx456 = fadd reassoc contract <4 x double> %.lcssa467, %.lcssa468
  %107 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx456)
  %cmp.n442 = icmp eq i64 %arraylen129, %n.vec440
  br i1 %cmp.n442, label %L124, label %scalar.ph436

scalar.ph436:                                     ; preds = %middle.block435, %L54.lr.ph
  %bc.resume.val441 = phi i64 [ %n.vec440, %middle.block435 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx457 = phi double [ %107, %middle.block435 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx459 = phi double [ %106, %middle.block435 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx461 = phi double [ %105, %middle.block435 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph436
  %value_phi25223 = phi double [ %bc.merge.rdx457, %scalar.ph436 ], [ %112, %L54 ]
  %value_phi24222 = phi i64 [ %bc.resume.val441, %scalar.ph436 ], [ %117, %L54 ]
  %value_phi23221 = phi double [ %bc.merge.rdx459, %scalar.ph436 ], [ %114, %L54 ]
  %value_phi22220 = phi double [ %bc.merge.rdx461, %scalar.ph436 ], [ %116, %L54 ]
  %108 = add i64 %35, %value_phi24222
  %109 = getelementptr inbounds double, double* %arrayptr27170, i64 %108
  %arrayref28 = load double, double* %109, align 8
  %110 = getelementptr inbounds double, double* %arrayptr30171, i64 %value_phi24222
  %arrayref31 = load double, double* %110, align 8
  %111 = fmul contract double %arrayref28, %arrayref28
  %112 = fadd reassoc contract double %value_phi25223, %111
  %113 = fmul contract double %arrayref28, %arrayref31
  %114 = fadd reassoc contract double %value_phi23221, %113
  %115 = fmul contract double %arrayref31, %arrayref31
  %116 = fadd reassoc contract double %value_phi22220, %115
  %117 = add nuw nsw i64 %value_phi24222, 1
  %exitcond.not = icmp eq i64 %117, %arraylen129
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not184, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %118 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr135 = getelementptr inbounds {}*, {}** %118, i64 3
  %119 = bitcast {}** %arraysize_ptr135 to i64*
  %arraysize136 = load i64, i64* %119, align 8
  %120 = mul i64 %arraysize136, %31
  %121 = bitcast {}* %getfield12 to double**
  %arrayptr139186 = load double*, double** %121, align 8
  %122 = bitcast {}* %getfield14 to double**
  %arrayptr142187 = load double*, double** %122, align 8
  %min.iters.check414 = icmp ult i64 %arraylen129, 8
  br i1 %min.iters.check414, label %scalar.ph413, label %vector.ph415

vector.ph415:                                     ; preds = %L96.lr.ph
  %n.vec417 = and i64 %arraylen129, 9223372036854775800
  %123 = add nsw i64 %n.vec417, -8
  %124 = lshr exact i64 %123, 3
  %125 = add nuw nsw i64 %124, 1
  %xtraiter523 = and i64 %125, 1
  %126 = icmp eq i64 %123, 0
  br i1 %126, label %middle.block412.unr-lcssa, label %vector.ph415.new

vector.ph415.new:                                 ; preds = %vector.ph415
  %unroll_iter529 = and i64 %125, 4611686018427387902
  br label %vector.body420

vector.body420:                                   ; preds = %vector.body420, %vector.ph415.new
  %index421 = phi i64 [ 0, %vector.ph415.new ], [ %index.next430.1, %vector.body420 ]
  %vec.phi422 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415.new ], [ %155, %vector.body420 ]
  %vec.phi423 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415.new ], [ %156, %vector.body420 ]
  %vec.phi424 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415.new ], [ %159, %vector.body420 ]
  %vec.phi425 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415.new ], [ %160, %vector.body420 ]
  %niter530 = phi i64 [ 0, %vector.ph415.new ], [ %niter530.next.1, %vector.body420 ]
  %127 = add i64 %120, %index421
  %128 = getelementptr inbounds double, double* %arrayptr139186, i64 %127
  %129 = bitcast double* %128 to <4 x double>*
  %wide.load426 = load <4 x double>, <4 x double>* %129, align 8
  %130 = getelementptr inbounds double, double* %128, i64 4
  %131 = bitcast double* %130 to <4 x double>*
  %wide.load427 = load <4 x double>, <4 x double>* %131, align 8
  %132 = getelementptr inbounds double, double* %arrayptr142187, i64 %index421
  %133 = bitcast double* %132 to <4 x double>*
  %wide.load428 = load <4 x double>, <4 x double>* %133, align 8
  %134 = getelementptr inbounds double, double* %132, i64 4
  %135 = bitcast double* %134 to <4 x double>*
  %wide.load429 = load <4 x double>, <4 x double>* %135, align 8
  %136 = fmul contract <4 x double> %wide.load426, %wide.load428
  %137 = fmul contract <4 x double> %wide.load427, %wide.load429
  %138 = fadd reassoc contract <4 x double> %vec.phi422, %136
  %139 = fadd reassoc contract <4 x double> %vec.phi423, %137
  %140 = fmul contract <4 x double> %wide.load428, %wide.load428
  %141 = fmul contract <4 x double> %wide.load429, %wide.load429
  %142 = fadd reassoc contract <4 x double> %vec.phi424, %140
  %143 = fadd reassoc contract <4 x double> %vec.phi425, %141
  %index.next430 = or i64 %index421, 8
  %144 = add i64 %120, %index.next430
  %145 = getelementptr inbounds double, double* %arrayptr139186, i64 %144
  %146 = bitcast double* %145 to <4 x double>*
  %wide.load426.1 = load <4 x double>, <4 x double>* %146, align 8
  %147 = getelementptr inbounds double, double* %145, i64 4
  %148 = bitcast double* %147 to <4 x double>*
  %wide.load427.1 = load <4 x double>, <4 x double>* %148, align 8
  %149 = getelementptr inbounds double, double* %arrayptr142187, i64 %index.next430
  %150 = bitcast double* %149 to <4 x double>*
  %wide.load428.1 = load <4 x double>, <4 x double>* %150, align 8
  %151 = getelementptr inbounds double, double* %149, i64 4
  %152 = bitcast double* %151 to <4 x double>*
  %wide.load429.1 = load <4 x double>, <4 x double>* %152, align 8
  %153 = fmul contract <4 x double> %wide.load426.1, %wide.load428.1
  %154 = fmul contract <4 x double> %wide.load427.1, %wide.load429.1
  %155 = fadd reassoc contract <4 x double> %138, %153
  %156 = fadd reassoc contract <4 x double> %139, %154
  %157 = fmul contract <4 x double> %wide.load428.1, %wide.load428.1
  %158 = fmul contract <4 x double> %wide.load429.1, %wide.load429.1
  %159 = fadd reassoc contract <4 x double> %142, %157
  %160 = fadd reassoc contract <4 x double> %143, %158
  %index.next430.1 = add nuw i64 %index421, 16
  %niter530.next.1 = add i64 %niter530, 2
  %niter530.ncmp.1 = icmp eq i64 %niter530.next.1, %unroll_iter529
  br i1 %niter530.ncmp.1, label %middle.block412.unr-lcssa, label %vector.body420

middle.block412.unr-lcssa:                        ; preds = %vector.body420, %vector.ph415
  %.lcssa475.ph = phi <4 x double> [ undef, %vector.ph415 ], [ %155, %vector.body420 ]
  %.lcssa474.ph = phi <4 x double> [ undef, %vector.ph415 ], [ %156, %vector.body420 ]
  %.lcssa473.ph = phi <4 x double> [ undef, %vector.ph415 ], [ %159, %vector.body420 ]
  %.lcssa472.ph = phi <4 x double> [ undef, %vector.ph415 ], [ %160, %vector.body420 ]
  %index421.unr = phi i64 [ 0, %vector.ph415 ], [ %index.next430.1, %vector.body420 ]
  %vec.phi422.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %155, %vector.body420 ]
  %vec.phi423.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %156, %vector.body420 ]
  %vec.phi424.unr = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %159, %vector.body420 ]
  %vec.phi425.unr = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %160, %vector.body420 ]
  %lcmp.mod524.not = icmp eq i64 %xtraiter523, 0
  br i1 %lcmp.mod524.not, label %middle.block412, label %vector.body420.epil.preheader

vector.body420.epil.preheader:                    ; preds = %middle.block412.unr-lcssa
  %161 = add i64 %120, %index421.unr
  %162 = getelementptr inbounds double, double* %arrayptr139186, i64 %161
  %163 = bitcast double* %162 to <4 x double>*
  %wide.load426.epil = load <4 x double>, <4 x double>* %163, align 8
  %164 = getelementptr inbounds double, double* %162, i64 4
  %165 = bitcast double* %164 to <4 x double>*
  %wide.load427.epil = load <4 x double>, <4 x double>* %165, align 8
  %166 = getelementptr inbounds double, double* %arrayptr142187, i64 %index421.unr
  %167 = bitcast double* %166 to <4 x double>*
  %wide.load428.epil = load <4 x double>, <4 x double>* %167, align 8
  %168 = getelementptr inbounds double, double* %166, i64 4
  %169 = bitcast double* %168 to <4 x double>*
  %wide.load429.epil = load <4 x double>, <4 x double>* %169, align 8
  %170 = fmul contract <4 x double> %wide.load426.epil, %wide.load428.epil
  %171 = fmul contract <4 x double> %wide.load427.epil, %wide.load429.epil
  %172 = fadd reassoc contract <4 x double> %vec.phi422.unr, %170
  %173 = fadd reassoc contract <4 x double> %vec.phi423.unr, %171
  %174 = fmul contract <4 x double> %wide.load428.epil, %wide.load428.epil
  %175 = fmul contract <4 x double> %wide.load429.epil, %wide.load429.epil
  %176 = fadd reassoc contract <4 x double> %vec.phi424.unr, %174
  %177 = fadd reassoc contract <4 x double> %vec.phi425.unr, %175
  br label %middle.block412

middle.block412:                                  ; preds = %vector.body420.epil.preheader, %middle.block412.unr-lcssa
  %.lcssa475 = phi <4 x double> [ %.lcssa475.ph, %middle.block412.unr-lcssa ], [ %172, %vector.body420.epil.preheader ]
  %.lcssa474 = phi <4 x double> [ %.lcssa474.ph, %middle.block412.unr-lcssa ], [ %173, %vector.body420.epil.preheader ]
  %.lcssa473 = phi <4 x double> [ %.lcssa473.ph, %middle.block412.unr-lcssa ], [ %176, %vector.body420.epil.preheader ]
  %.lcssa472 = phi <4 x double> [ %.lcssa472.ph, %middle.block412.unr-lcssa ], [ %177, %vector.body420.epil.preheader ]
  %bin.rdx433 = fadd reassoc contract <4 x double> %.lcssa472, %.lcssa473
  %178 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx433)
  %bin.rdx431 = fadd reassoc contract <4 x double> %.lcssa474, %.lcssa475
  %179 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx431)
  %cmp.n419 = icmp eq i64 %arraylen129, %n.vec417
  br i1 %cmp.n419, label %L124, label %scalar.ph413

scalar.ph413:                                     ; preds = %middle.block412, %L96.lr.ph
  %bc.resume.val418 = phi i64 [ %n.vec417, %middle.block412 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx432 = phi double [ %179, %middle.block412 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx434 = phi double [ %178, %middle.block412 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph413
  %value_phi134229 = phi i64 [ %bc.resume.val418, %scalar.ph413 ], [ %187, %L96 ]
  %value_phi133228 = phi double [ %bc.merge.rdx432, %scalar.ph413 ], [ %184, %L96 ]
  %value_phi132227 = phi double [ %bc.merge.rdx434, %scalar.ph413 ], [ %186, %L96 ]
  %180 = add i64 %120, %value_phi134229
  %181 = getelementptr inbounds double, double* %arrayptr139186, i64 %180
  %arrayref140 = load double, double* %181, align 8
  %182 = getelementptr inbounds double, double* %arrayptr142187, i64 %value_phi134229
  %arrayref143 = load double, double* %182, align 8
  %183 = fmul contract double %arrayref140, %arrayref143
  %184 = fadd reassoc contract double %value_phi133228, %183
  %185 = fmul contract double %arrayref143, %arrayref143
  %186 = fadd reassoc contract double %value_phi132227, %185
  %187 = add nuw nsw i64 %value_phi134229, 1
  %exitcond284.not = icmp eq i64 %187, %arraylen129
  br i1 %exitcond284.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block412, %L83, %L54, %middle.block435, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %178, %middle.block412 ], [ %105, %middle.block435 ], [ %186, %L96 ], [ %116, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %179, %middle.block412 ], [ %106, %middle.block435 ], [ %184, %L96 ], [ %114, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block412 ], [ %107, %middle.block435 ], [ %arrayref, %L96 ], [ %112, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %31, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L145:                                             ; preds = %idxend46
  store i64 %arraysize55, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %23, align 8
  %188 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 4
  store {}* %getfield53, {}** %188, align 16
  call void @j_throw_boundserror_1318({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct59) #3
  unreachable

L148:                                             ; preds = %idxend46
  %189 = mul i64 %arraysize55, %31
  %190 = bitcast {}* %getfield51 to i8*
  %getfield_addr71 = getelementptr inbounds i8, i8* %190, i64 24
  %191 = bitcast i8* %getfield_addr71 to {}**
  %getfield72 = load atomic {}*, {}** %191 unordered, align 8
  %192 = load i64, i64* %26, align 1
  store i64 %192, i64* %27, align 8
  %193 = bitcast {}* %getfield72 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr73 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %193, i64 0, i32 1
  %arraylen74 = load i64, i64* %arraylen_ptr73, align 8
  %194 = fsub double %value_phi40, %value_phi40
  %195 = fcmp ord double %194, 0.000000e+00
  %196 = sitofp i64 %arraylen74 to double
  %197 = fmul double %196, 0x350000000000000
  %198 = fcmp ole double %197, %value_phi40
  %199 = and i1 %195, %198
  %200 = fsub double %value_phi38, %value_phi38
  %201 = fcmp ord double %200, 0.000000e+00
  %202 = fcmp ole double %197, %value_phi38
  %203 = and i1 %201, %202
  %204 = and i1 %199, %203
  %205 = bitcast i64 %192 to double
  br i1 %204, label %L179, label %L356

L179:                                             ; preds = %L148
  %206 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %206, label %L184, label %L182

L182:                                             ; preds = %L179
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 140312453360144 to {}*), double %value_phi40) #3
  unreachable

L184:                                             ; preds = %L179
  %207 = call double @llvm.sqrt.f64(double %value_phi40)
  %208 = fcmp ugt double %207, %205
  br i1 %208, label %L189, label %L360

L189:                                             ; preds = %L184
  %209 = fdiv double %value_phi39, %value_phi40
  %210 = fadd double %209, %arrayref49
  %211 = fmul double %value_phi39, %209
  %212 = fsub double %value_phi38, %211
  %213 = fmul double %value_phi38, 6.250000e-02
  %214 = fcmp uge double %212, %213
  br i1 %214, label %L245, label %L196

L196:                                             ; preds = %L189
  %.not176 = icmp eq i64 %arraylen74, 0
  br i1 %.not176, label %L250, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L196
  %215 = bitcast {}* %getfield72 to double**
  %arrayptr92178 = load double*, double** %215, align 8
  %216 = bitcast {}* %getfield53 to double**
  %arrayptr96179 = load double*, double** %216, align 8
  %min.iters.check = icmp ult i64 %arraylen74, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen74, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %209, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %246, %vector.body ]
  %vec.phi394 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %247, %vector.body ]
  %vec.phi395 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %248, %vector.body ]
  %vec.phi396 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %249, %vector.body ]
  %217 = getelementptr inbounds double, double* %arrayptr92178, i64 %index
  %218 = bitcast double* %217 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %218, align 8
  %219 = getelementptr inbounds double, double* %217, i64 4
  %220 = bitcast double* %219 to <4 x double>*
  %wide.load397 = load <4 x double>, <4 x double>* %220, align 8
  %221 = getelementptr inbounds double, double* %217, i64 8
  %222 = bitcast double* %221 to <4 x double>*
  %wide.load398 = load <4 x double>, <4 x double>* %222, align 8
  %223 = getelementptr inbounds double, double* %217, i64 12
  %224 = bitcast double* %223 to <4 x double>*
  %wide.load399 = load <4 x double>, <4 x double>* %224, align 8
  %225 = add i64 %index, %189
  %226 = getelementptr inbounds double, double* %arrayptr96179, i64 %225
  %227 = bitcast double* %226 to <4 x double>*
  %wide.load400 = load <4 x double>, <4 x double>* %227, align 8
  %228 = getelementptr inbounds double, double* %226, i64 4
  %229 = bitcast double* %228 to <4 x double>*
  %wide.load401 = load <4 x double>, <4 x double>* %229, align 8
  %230 = getelementptr inbounds double, double* %226, i64 8
  %231 = bitcast double* %230 to <4 x double>*
  %wide.load402 = load <4 x double>, <4 x double>* %231, align 8
  %232 = getelementptr inbounds double, double* %226, i64 12
  %233 = bitcast double* %232 to <4 x double>*
  %wide.load403 = load <4 x double>, <4 x double>* %233, align 8
  %234 = fmul <4 x double> %broadcast.splat, %wide.load400
  %235 = fmul <4 x double> %broadcast.splat, %wide.load401
  %236 = fmul <4 x double> %broadcast.splat, %wide.load402
  %237 = fmul <4 x double> %broadcast.splat, %wide.load403
  %238 = fsub <4 x double> %wide.load, %234
  %239 = fsub <4 x double> %wide.load397, %235
  %240 = fsub <4 x double> %wide.load398, %236
  %241 = fsub <4 x double> %wide.load399, %237
  %242 = fmul contract <4 x double> %238, %238
  %243 = fmul contract <4 x double> %239, %239
  %244 = fmul contract <4 x double> %240, %240
  %245 = fmul contract <4 x double> %241, %241
  %246 = fadd reassoc contract <4 x double> %vec.phi, %242
  %247 = fadd reassoc contract <4 x double> %vec.phi394, %243
  %248 = fadd reassoc contract <4 x double> %vec.phi395, %244
  %249 = fadd reassoc contract <4 x double> %vec.phi396, %245
  %index.next = add nuw i64 %index, 16
  %250 = icmp eq i64 %index.next, %n.vec
  br i1 %250, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %247, %246
  %bin.rdx410 = fadd reassoc contract <4 x double> %248, %bin.rdx
  %bin.rdx411 = fadd reassoc contract <4 x double> %249, %bin.rdx410
  %251 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx411)
  %cmp.n = icmp eq i64 %arraylen74, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi double [ %251, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90234 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %259, %L208 ]
  %value_phi89233 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %258, %L208 ]
  %252 = getelementptr inbounds double, double* %arrayptr92178, i64 %value_phi90234
  %arrayref93 = load double, double* %252, align 8
  %253 = add i64 %value_phi90234, %189
  %254 = getelementptr inbounds double, double* %arrayptr96179, i64 %253
  %arrayref97 = load double, double* %254, align 8
  %255 = fmul double %209, %arrayref97
  %256 = fsub double %arrayref93, %255
  %257 = fmul contract double %256, %256
  %258 = fadd reassoc contract double %value_phi89233, %257
  %259 = add nuw nsw i64 %value_phi90234, 1
  %exitcond285.not = icmp eq i64 %259, %arraylen74
  br i1 %exitcond285.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L189
  %value_phi102 = phi double [ %212, %L189 ], [ %251, %middle.block ], [ %258, %L208 ]
  %260 = fcmp uge double %value_phi102, 0.000000e+00
  br i1 %260, label %L250, label %L248

L248:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 140312453360144 to {}*), double %value_phi102) #3
  unreachable

L250:                                             ; preds = %L245, %L196
  %value_phi102189 = phi double [ %value_phi102, %L245 ], [ 0.000000e+00, %L196 ]
  %261 = call double @llvm.sqrt.f64(double %value_phi102189)
  %262 = fsub double %207, %205
  %263 = fcmp uge double %262, 0.000000e+00
  br i1 %263, label %L257, label %L255

L255:                                             ; preds = %L250
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 140312453360144 to {}*), double %262) #3
  unreachable

L257:                                             ; preds = %L250
  %264 = fadd double %207, %205
  %265 = fcmp uge double %264, 0.000000e+00
  br i1 %265, label %L264, label %L262

L262:                                             ; preds = %L257
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 140312453360144 to {}*), double %264) #3
  unreachable

L264:                                             ; preds = %L257
  %266 = call double @llvm.sqrt.f64(double %262)
  %267 = call double @llvm.sqrt.f64(double %264)
  %268 = fmul double %266, %267
  %269 = fmul double %207, %268
  %270 = fdiv double %261, %269
  %271 = fmul double %270, %205
  %272 = fcmp oge double %269, 0x10000000000000
  %273 = fcmp oeq double %261, 0.000000e+00
  %274 = fcmp oge double %270, 0x10000000000000
  %275 = fcmp ole double %270, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %274, %275
  %276 = fcmp oge double %271, 0x10000000000000
  %277 = fcmp ole double %271, 0x7FEFFFFFFFFFFFFF
  %narrow180 = and i1 %276, %277
  %278 = and i1 %narrow, %narrow180
  %279 = or i1 %273, %278
  %280 = and i1 %272, %279
  br i1 %280, label %L288, label %L354

L288:                                             ; preds = %L264
  %281 = fcmp ult double %271, 0x10000000000000
  %282 = fcmp ugt double %271, 0x7FEFFFFFFFFFFFFF
  %283 = or i1 %281, %282
  br i1 %283, label %L323, label %L299

L299:                                             ; preds = %L288
  %284 = fneg double %271
  %.inv = fcmp ogt double %210, %284
  %285 = select i1 %.inv, double %210, double %284
  %.inv182 = fcmp olt double %285, %271
  %286 = select i1 %.inv182, double %285, double %271
  %287 = fsub double %210, %286
  %288 = fadd double %287, 0.000000e+00
  br label %L360

L323:                                             ; preds = %L288
  %289 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 5
  store {}* %getfield, {}** %289, align 8
  %290 = call double @j__exceptional_product_1316(double %270, double %205, double 1.000000e+00)
  %291 = fsub double %210, %290
  %bitcast_coercion = bitcast double %291 to i64
  %292 = icmp sgt i64 %bitcast_coercion, -1
  %293 = select i1 %292, double %291, double 0.000000e+00
  %294 = fcmp ord double %291, 0.000000e+00
  %295 = select i1 %294, double %293, double %291
  %296 = fadd double %210, %290
  %bitcast_coercion121 = bitcast double %296 to i64
  %297 = icmp sgt i64 %bitcast_coercion121, -1
  %298 = fcmp ord double %296, 0.000000e+00
  %299 = and i1 %298, %297
  %300 = select i1 %299, double 0.000000e+00, double %296
  %301 = fadd double %295, %300
  %302 = fcmp ult double %270, 0.000000e+00
  %303 = call double @llvm.fabs.f64(double %205)
  %304 = bitcast double %303 to i64
  %305 = icmp ne i64 %304, 9218868437227405312
  %ifelse_cond125 = or i1 %302, %305
  %306 = select i1 %ifelse_cond125, double %301, double 0.000000e+00
  br label %L360

L354:                                             ; preds = %L264
  store {}* %getfield53, {}** %5, align 16
  store {}* %getfield53, {}** %.fca.0.gep152, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep154, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep156, align 8
  store i64 %189, i64* %.fca.2.gep158, align 8
  store i64 1, i64* %.fca.3.gep160, align 8
  %307 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 5
  store {}* %getfield, {}** %307, align 8
  %308 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 4
  store {}* %getfield72, {}** %308, align 16
  %309 = call double @j__sqrt_cold_1317({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %6, {}* nonnull %getfield72, { double }* nocapture readonly %aggregate_load_box, double %arrayref49, double %value_phi40, i64 signext %value_phi9)
  br label %L360

L356:                                             ; preds = %L148
  store {}* %getfield53, {}** %4, align 8
  store {}* %getfield53, {}** %.fca.0.gep, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep, align 8
  store i64 %189, i64* %.fca.2.gep, align 8
  store i64 1, i64* %.fca.3.gep, align 8
  %310 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 5
  store {}* %getfield, {}** %310, align 8
  %311 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe532, i64 0, i64 4
  store {}* %getfield72, {}** %311, align 16
  %312 = call double @j__sqrt_cold_1317({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %7, {}* nonnull %getfield72, { double }* nocapture readonly %aggregate_load_box, double %arrayref49, double %value_phi40, i64 signext %value_phi9)
  br label %L360

L360:                                             ; preds = %L356, %L354, %L323, %L299, %L184
  %value_phi77 = phi double [ %309, %L354 ], [ %312, %L356 ], [ 0.000000e+00, %L184 ], [ %288, %L299 ], [ %306, %L323 ]
  %313 = fadd double %value_phi8, %value_phi77
  %.not174.not = icmp eq i64 %value_phi9, %arraylen
  %314 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not174.not, label %L372, label %L31

L372:                                             ; preds = %L360, %L17
  %value_phi9.lcssa263274 = phi i64 [ %value_phi9.lcssa263275, %L17 ], [ %arraylen, %L360 ]
  %arraysize55.lcssa248265 = phi i64 [ %arraysize55.lcssa248266, %L17 ], [ %arraysize55, %L360 ]
  %value_phi81 = phi double [ %value_phi4, %L17 ], [ %313, %L360 ]
  %.not175 = icmp eq i64 %value_phi3, %15
  br i1 %.not175, label %L383.loopexit, label %L17thread-pre-split

L383.loopexit:                                    ; preds = %L372, %L17.preheader
  %.us-phi = phi i64 [ undef, %L17.preheader ], [ %value_phi9.lcssa263274, %L372 ]
  %.us-phi282 = phi i64 [ undef, %L17.preheader ], [ %arraysize55.lcssa248265, %L372 ]
  %.us-phi283 = phi double [ 0.000000e+00, %L17.preheader ], [ %value_phi81, %L372 ]
  store i64 %.us-phi282, i64* %memcpy_refined_dst, align 8
  store i64 %.us-phi, i64* %23, align 8
  br label %L383

L383:                                             ; preds = %L383.loopexit, %top
  %value_phi84 = phi double [ 0.000000e+00, %top ], [ %.us-phi283, %L383.loopexit ]
  %315 = load {}*, {}** %10, align 8
  %316 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %315, {}** %316, align 8
  ret double %value_phi84

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %317 = bitcast {}* %getfield16 to double**
  %arrayptr168 = load double*, double** %317, align 8
  %318 = getelementptr inbounds double, double* %arrayptr168, i64 %31
  %arrayref = load double, double* %318, align 8
  %319 = fcmp ord double %arrayref, 0.000000e+00
  %320 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr128 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %320, i64 0, i32 1
  %arraylen129 = load i64, i64* %arraylen_ptr128, align 8
  %.not184 = icmp eq i64 %arraylen129, 0
  br i1 %319, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48172 = load double*, double** %22, align 8
  %321 = getelementptr inbounds double, double* %arrayptr48172, i64 %31
  %arrayref49 = load double, double* %321, align 8
  %getfield51 = load atomic {}*, {}** %14 unordered, align 8
  %322 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %322 unordered, align 8
  %323 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr54 = getelementptr inbounds {}*, {}** %323, i64 3
  %324 = bitcast {}** %arraysize_ptr54 to i64*
  %arraysize55 = load i64, i64* %324, align 8
  %arraysize_ptr60 = getelementptr inbounds {}*, {}** %323, i64 4
  %325 = bitcast {}** %arraysize_ptr60 to i64*
  %arraysize61 = load i64, i64* %325, align 8
  %.not173 = icmp ult i64 %31, %arraysize61
  br i1 %.not173, label %L148, label %L145
}
