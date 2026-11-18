; Function Attrs: noinline
define double @julia_pass_1311({}* noundef nonnull align 8 dereferenceable(80) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe518 = alloca [6 x {}*], align 16
  %gcframe518.sub = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 0
  %3 = bitcast [6 x {}*]* %gcframe518 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 48, i1 true)
  %4 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 3
  %5 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 2
  %newstruct59 = alloca { [1 x [1 x i64]], i64 }, align 8
  %aggregate_load_box = alloca { double }, align 8
  %6 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %7 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #15
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [6 x {}*]* %gcframe518 to i64*
  store i64 16, i64* %9, align 16
  %10 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe518.sub, {}*** %13, align 8
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
  %value_phi8 = phi double [ %231, %L360 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %232, %L360 ], [ 1, %L17 ]
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
  br label %vector.body443

vector.body443:                                   ; preds = %vector.body443, %vector.ph438
  %index444 = phi i64 [ 0, %vector.ph438 ], [ %index.next455, %vector.body443 ]
  %vec.phi445 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %49, %vector.body443 ]
  %vec.phi446 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %50, %vector.body443 ]
  %vec.phi447 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %53, %vector.body443 ]
  %vec.phi448 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %54, %vector.body443 ]
  %vec.phi449 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %57, %vector.body443 ]
  %vec.phi450 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph438 ], [ %58, %vector.body443 ]
  %38 = add i64 %35, %index444
  %39 = getelementptr inbounds double, double* %arrayptr27170, i64 %38
  %40 = bitcast double* %39 to <4 x double>*
  %wide.load451 = load <4 x double>, <4 x double>* %40, align 8
  %41 = getelementptr inbounds double, double* %39, i64 4
  %42 = bitcast double* %41 to <4 x double>*
  %wide.load452 = load <4 x double>, <4 x double>* %42, align 8
  %43 = getelementptr inbounds double, double* %arrayptr30171, i64 %index444
  %44 = bitcast double* %43 to <4 x double>*
  %wide.load453 = load <4 x double>, <4 x double>* %44, align 8
  %45 = getelementptr inbounds double, double* %43, i64 4
  %46 = bitcast double* %45 to <4 x double>*
  %wide.load454 = load <4 x double>, <4 x double>* %46, align 8
  %47 = fmul contract <4 x double> %wide.load451, %wide.load451
  %48 = fmul contract <4 x double> %wide.load452, %wide.load452
  %49 = fadd reassoc contract <4 x double> %vec.phi445, %47
  %50 = fadd reassoc contract <4 x double> %vec.phi446, %48
  %51 = fmul contract <4 x double> %wide.load451, %wide.load453
  %52 = fmul contract <4 x double> %wide.load452, %wide.load454
  %53 = fadd reassoc contract <4 x double> %vec.phi447, %51
  %54 = fadd reassoc contract <4 x double> %vec.phi448, %52
  %55 = fmul contract <4 x double> %wide.load453, %wide.load453
  %56 = fmul contract <4 x double> %wide.load454, %wide.load454
  %57 = fadd reassoc contract <4 x double> %vec.phi449, %55
  %58 = fadd reassoc contract <4 x double> %vec.phi450, %56
  %index.next455 = add nuw i64 %index444, 8
  %59 = icmp eq i64 %index.next455, %n.vec440
  br i1 %59, label %middle.block435, label %vector.body443

middle.block435:                                  ; preds = %vector.body443
  %bin.rdx460 = fadd reassoc contract <4 x double> %58, %57
  %60 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx460)
  %bin.rdx458 = fadd reassoc contract <4 x double> %54, %53
  %61 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx458)
  %bin.rdx456 = fadd reassoc contract <4 x double> %50, %49
  %62 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx456)
  %cmp.n442 = icmp eq i64 %arraylen129, %n.vec440
  br i1 %cmp.n442, label %L124, label %scalar.ph436

scalar.ph436:                                     ; preds = %middle.block435, %L54.lr.ph
  %bc.resume.val441 = phi i64 [ %n.vec440, %middle.block435 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx457 = phi double [ %62, %middle.block435 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx459 = phi double [ %61, %middle.block435 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx461 = phi double [ %60, %middle.block435 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph436
  %value_phi25223 = phi double [ %bc.merge.rdx457, %scalar.ph436 ], [ %67, %L54 ]
  %value_phi24222 = phi i64 [ %bc.resume.val441, %scalar.ph436 ], [ %72, %L54 ]
  %value_phi23221 = phi double [ %bc.merge.rdx459, %scalar.ph436 ], [ %69, %L54 ]
  %value_phi22220 = phi double [ %bc.merge.rdx461, %scalar.ph436 ], [ %71, %L54 ]
  %63 = add i64 %35, %value_phi24222
  %64 = getelementptr inbounds double, double* %arrayptr27170, i64 %63
  %arrayref28 = load double, double* %64, align 8
  %65 = getelementptr inbounds double, double* %arrayptr30171, i64 %value_phi24222
  %arrayref31 = load double, double* %65, align 8
  %66 = fmul contract double %arrayref28, %arrayref28
  %67 = fadd reassoc contract double %value_phi25223, %66
  %68 = fmul contract double %arrayref28, %arrayref31
  %69 = fadd reassoc contract double %value_phi23221, %68
  %70 = fmul contract double %arrayref31, %arrayref31
  %71 = fadd reassoc contract double %value_phi22220, %70
  %72 = add nuw nsw i64 %value_phi24222, 1
  %exitcond.not = icmp eq i64 %72, %arraylen129
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not184, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %73 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr135 = getelementptr inbounds {}*, {}** %73, i64 3
  %74 = bitcast {}** %arraysize_ptr135 to i64*
  %arraysize136 = load i64, i64* %74, align 8
  %75 = mul i64 %arraysize136, %31
  %76 = bitcast {}* %getfield12 to double**
  %arrayptr139186 = load double*, double** %76, align 8
  %77 = bitcast {}* %getfield14 to double**
  %arrayptr142187 = load double*, double** %77, align 8
  %min.iters.check414 = icmp ult i64 %arraylen129, 8
  br i1 %min.iters.check414, label %scalar.ph413, label %vector.ph415

vector.ph415:                                     ; preds = %L96.lr.ph
  %n.vec417 = and i64 %arraylen129, 9223372036854775800
  br label %vector.body420

vector.body420:                                   ; preds = %vector.body420, %vector.ph415
  %index421 = phi i64 [ 0, %vector.ph415 ], [ %index.next430, %vector.body420 ]
  %vec.phi422 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %89, %vector.body420 ]
  %vec.phi423 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %90, %vector.body420 ]
  %vec.phi424 = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %93, %vector.body420 ]
  %vec.phi425 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph415 ], [ %94, %vector.body420 ]
  %78 = add i64 %75, %index421
  %79 = getelementptr inbounds double, double* %arrayptr139186, i64 %78
  %80 = bitcast double* %79 to <4 x double>*
  %wide.load426 = load <4 x double>, <4 x double>* %80, align 8
  %81 = getelementptr inbounds double, double* %79, i64 4
  %82 = bitcast double* %81 to <4 x double>*
  %wide.load427 = load <4 x double>, <4 x double>* %82, align 8
  %83 = getelementptr inbounds double, double* %arrayptr142187, i64 %index421
  %84 = bitcast double* %83 to <4 x double>*
  %wide.load428 = load <4 x double>, <4 x double>* %84, align 8
  %85 = getelementptr inbounds double, double* %83, i64 4
  %86 = bitcast double* %85 to <4 x double>*
  %wide.load429 = load <4 x double>, <4 x double>* %86, align 8
  %87 = fmul contract <4 x double> %wide.load426, %wide.load428
  %88 = fmul contract <4 x double> %wide.load427, %wide.load429
  %89 = fadd reassoc contract <4 x double> %vec.phi422, %87
  %90 = fadd reassoc contract <4 x double> %vec.phi423, %88
  %91 = fmul contract <4 x double> %wide.load428, %wide.load428
  %92 = fmul contract <4 x double> %wide.load429, %wide.load429
  %93 = fadd reassoc contract <4 x double> %vec.phi424, %91
  %94 = fadd reassoc contract <4 x double> %vec.phi425, %92
  %index.next430 = add nuw i64 %index421, 8
  %95 = icmp eq i64 %index.next430, %n.vec417
  br i1 %95, label %middle.block412, label %vector.body420

middle.block412:                                  ; preds = %vector.body420
  %bin.rdx433 = fadd reassoc contract <4 x double> %94, %93
  %96 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx433)
  %bin.rdx431 = fadd reassoc contract <4 x double> %90, %89
  %97 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx431)
  %cmp.n419 = icmp eq i64 %arraylen129, %n.vec417
  br i1 %cmp.n419, label %L124, label %scalar.ph413

scalar.ph413:                                     ; preds = %middle.block412, %L96.lr.ph
  %bc.resume.val418 = phi i64 [ %n.vec417, %middle.block412 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx432 = phi double [ %97, %middle.block412 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx434 = phi double [ %96, %middle.block412 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph413
  %value_phi134229 = phi i64 [ %bc.resume.val418, %scalar.ph413 ], [ %105, %L96 ]
  %value_phi133228 = phi double [ %bc.merge.rdx432, %scalar.ph413 ], [ %102, %L96 ]
  %value_phi132227 = phi double [ %bc.merge.rdx434, %scalar.ph413 ], [ %104, %L96 ]
  %98 = add i64 %75, %value_phi134229
  %99 = getelementptr inbounds double, double* %arrayptr139186, i64 %98
  %arrayref140 = load double, double* %99, align 8
  %100 = getelementptr inbounds double, double* %arrayptr142187, i64 %value_phi134229
  %arrayref143 = load double, double* %100, align 8
  %101 = fmul contract double %arrayref140, %arrayref143
  %102 = fadd reassoc contract double %value_phi133228, %101
  %103 = fmul contract double %arrayref143, %arrayref143
  %104 = fadd reassoc contract double %value_phi132227, %103
  %105 = add nuw nsw i64 %value_phi134229, 1
  %exitcond284.not = icmp eq i64 %105, %arraylen129
  br i1 %exitcond284.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block412, %L83, %L54, %middle.block435, %L40
  %value_phi38 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %96, %middle.block412 ], [ %60, %middle.block435 ], [ %104, %L96 ], [ %71, %L54 ]
  %value_phi39 = phi double [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %97, %middle.block412 ], [ %61, %middle.block435 ], [ %102, %L96 ], [ %69, %L54 ]
  %value_phi40 = phi double [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block412 ], [ %62, %middle.block435 ], [ %arrayref, %L96 ], [ %67, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %31, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L145:                                             ; preds = %idxend46
  store i64 %arraysize55, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %23, align 8
  %106 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 4
  store {}* %getfield53, {}** %106, align 16
  call void @j_throw_boundserror_1318({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct59) #3
  unreachable

L148:                                             ; preds = %idxend46
  %107 = mul i64 %arraysize55, %31
  %108 = bitcast {}* %getfield51 to i8*
  %getfield_addr71 = getelementptr inbounds i8, i8* %108, i64 24
  %109 = bitcast i8* %getfield_addr71 to {}**
  %getfield72 = load atomic {}*, {}** %109 unordered, align 8
  %110 = load i64, i64* %26, align 1
  store i64 %110, i64* %27, align 8
  %111 = bitcast {}* %getfield72 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr73 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %111, i64 0, i32 1
  %arraylen74 = load i64, i64* %arraylen_ptr73, align 8
  %112 = fsub double %value_phi40, %value_phi40
  %113 = fcmp ord double %112, 0.000000e+00
  %114 = sitofp i64 %arraylen74 to double
  %115 = fmul double %114, 0x350000000000000
  %116 = fcmp ole double %115, %value_phi40
  %117 = and i1 %113, %116
  %118 = fsub double %value_phi38, %value_phi38
  %119 = fcmp ord double %118, 0.000000e+00
  %120 = fcmp ole double %115, %value_phi38
  %121 = and i1 %119, %120
  %122 = and i1 %117, %121
  %123 = bitcast i64 %110 to double
  br i1 %122, label %L179, label %L356

L179:                                             ; preds = %L148
  %124 = fcmp uge double %value_phi40, 0.000000e+00
  br i1 %124, label %L184, label %L182

L182:                                             ; preds = %L179
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 136709640595984 to {}*), double %value_phi40) #3
  unreachable

L184:                                             ; preds = %L179
  %125 = call double @llvm.sqrt.f64(double %value_phi40)
  %126 = fcmp ugt double %125, %123
  br i1 %126, label %L189, label %L360

L189:                                             ; preds = %L184
  %127 = fdiv double %value_phi39, %value_phi40
  %128 = fadd double %127, %arrayref49
  %129 = fmul double %value_phi39, %127
  %130 = fsub double %value_phi38, %129
  %131 = fmul double %value_phi38, 6.250000e-02
  %132 = fcmp uge double %130, %131
  br i1 %132, label %L245, label %L196

L196:                                             ; preds = %L189
  %.not176 = icmp eq i64 %arraylen74, 0
  br i1 %.not176, label %L250, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L196
  %133 = bitcast {}* %getfield72 to double**
  %arrayptr92178 = load double*, double** %133, align 8
  %134 = bitcast {}* %getfield53 to double**
  %arrayptr96179 = load double*, double** %134, align 8
  %min.iters.check = icmp ult i64 %arraylen74, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen74, 9223372036854775792
  %broadcast.splatinsert = insertelement <4 x double> poison, double %127, i64 0
  %broadcast.splat = shufflevector <4 x double> %broadcast.splatinsert, <4 x double> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <4 x double> [ <double 0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %164, %vector.body ]
  %vec.phi394 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %165, %vector.body ]
  %vec.phi395 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %166, %vector.body ]
  %vec.phi396 = phi <4 x double> [ <double -0.000000e+00, double -0.000000e+00, double -0.000000e+00, double -0.000000e+00>, %vector.ph ], [ %167, %vector.body ]
  %135 = getelementptr inbounds double, double* %arrayptr92178, i64 %index
  %136 = bitcast double* %135 to <4 x double>*
  %wide.load = load <4 x double>, <4 x double>* %136, align 8
  %137 = getelementptr inbounds double, double* %135, i64 4
  %138 = bitcast double* %137 to <4 x double>*
  %wide.load397 = load <4 x double>, <4 x double>* %138, align 8
  %139 = getelementptr inbounds double, double* %135, i64 8
  %140 = bitcast double* %139 to <4 x double>*
  %wide.load398 = load <4 x double>, <4 x double>* %140, align 8
  %141 = getelementptr inbounds double, double* %135, i64 12
  %142 = bitcast double* %141 to <4 x double>*
  %wide.load399 = load <4 x double>, <4 x double>* %142, align 8
  %143 = add i64 %index, %107
  %144 = getelementptr inbounds double, double* %arrayptr96179, i64 %143
  %145 = bitcast double* %144 to <4 x double>*
  %wide.load400 = load <4 x double>, <4 x double>* %145, align 8
  %146 = getelementptr inbounds double, double* %144, i64 4
  %147 = bitcast double* %146 to <4 x double>*
  %wide.load401 = load <4 x double>, <4 x double>* %147, align 8
  %148 = getelementptr inbounds double, double* %144, i64 8
  %149 = bitcast double* %148 to <4 x double>*
  %wide.load402 = load <4 x double>, <4 x double>* %149, align 8
  %150 = getelementptr inbounds double, double* %144, i64 12
  %151 = bitcast double* %150 to <4 x double>*
  %wide.load403 = load <4 x double>, <4 x double>* %151, align 8
  %152 = fmul <4 x double> %broadcast.splat, %wide.load400
  %153 = fmul <4 x double> %broadcast.splat, %wide.load401
  %154 = fmul <4 x double> %broadcast.splat, %wide.load402
  %155 = fmul <4 x double> %broadcast.splat, %wide.load403
  %156 = fsub <4 x double> %wide.load, %152
  %157 = fsub <4 x double> %wide.load397, %153
  %158 = fsub <4 x double> %wide.load398, %154
  %159 = fsub <4 x double> %wide.load399, %155
  %160 = fmul contract <4 x double> %156, %156
  %161 = fmul contract <4 x double> %157, %157
  %162 = fmul contract <4 x double> %158, %158
  %163 = fmul contract <4 x double> %159, %159
  %164 = fadd reassoc contract <4 x double> %vec.phi, %160
  %165 = fadd reassoc contract <4 x double> %vec.phi394, %161
  %166 = fadd reassoc contract <4 x double> %vec.phi395, %162
  %167 = fadd reassoc contract <4 x double> %vec.phi396, %163
  %index.next = add nuw i64 %index, 16
  %168 = icmp eq i64 %index.next, %n.vec
  br i1 %168, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <4 x double> %165, %164
  %bin.rdx410 = fadd reassoc contract <4 x double> %166, %bin.rdx
  %bin.rdx411 = fadd reassoc contract <4 x double> %167, %bin.rdx410
  %169 = call reassoc contract double @llvm.vector.reduce.fadd.v4f64(double -0.000000e+00, <4 x double> %bin.rdx411)
  %cmp.n = icmp eq i64 %arraylen74, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi double [ %169, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90234 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %177, %L208 ]
  %value_phi89233 = phi double [ %bc.merge.rdx, %scalar.ph ], [ %176, %L208 ]
  %170 = getelementptr inbounds double, double* %arrayptr92178, i64 %value_phi90234
  %arrayref93 = load double, double* %170, align 8
  %171 = add i64 %value_phi90234, %107
  %172 = getelementptr inbounds double, double* %arrayptr96179, i64 %171
  %arrayref97 = load double, double* %172, align 8
  %173 = fmul double %127, %arrayref97
  %174 = fsub double %arrayref93, %173
  %175 = fmul contract double %174, %174
  %176 = fadd reassoc contract double %value_phi89233, %175
  %177 = add nuw nsw i64 %value_phi90234, 1
  %exitcond285.not = icmp eq i64 %177, %arraylen74
  br i1 %exitcond285.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L189
  %value_phi102 = phi double [ %130, %L189 ], [ %169, %middle.block ], [ %176, %L208 ]
  %178 = fcmp uge double %value_phi102, 0.000000e+00
  br i1 %178, label %L250, label %L248

L248:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 136709640595984 to {}*), double %value_phi102) #3
  unreachable

L250:                                             ; preds = %L245, %L196
  %value_phi102189 = phi double [ %value_phi102, %L245 ], [ 0.000000e+00, %L196 ]
  %179 = call double @llvm.sqrt.f64(double %value_phi102189)
  %180 = fsub double %125, %123
  %181 = fcmp uge double %180, 0.000000e+00
  br i1 %181, label %L257, label %L255

L255:                                             ; preds = %L250
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 136709640595984 to {}*), double %180) #3
  unreachable

L257:                                             ; preds = %L250
  %182 = fadd double %125, %123
  %183 = fcmp uge double %182, 0.000000e+00
  br i1 %183, label %L264, label %L262

L262:                                             ; preds = %L257
  call void @j_throw_complex_domainerror_1314({}* inttoptr (i64 136709640595984 to {}*), double %182) #3
  unreachable

L264:                                             ; preds = %L257
  %184 = call double @llvm.sqrt.f64(double %180)
  %185 = call double @llvm.sqrt.f64(double %182)
  %186 = fmul double %184, %185
  %187 = fmul double %125, %186
  %188 = fdiv double %179, %187
  %189 = fmul double %188, %123
  %190 = fcmp oge double %187, 0x10000000000000
  %191 = fcmp oeq double %179, 0.000000e+00
  %192 = fcmp oge double %188, 0x10000000000000
  %193 = fcmp ole double %188, 0x7FEFFFFFFFFFFFFF
  %narrow = and i1 %192, %193
  %194 = fcmp oge double %189, 0x10000000000000
  %195 = fcmp ole double %189, 0x7FEFFFFFFFFFFFFF
  %narrow180 = and i1 %194, %195
  %196 = and i1 %narrow, %narrow180
  %197 = or i1 %191, %196
  %198 = and i1 %190, %197
  br i1 %198, label %L288, label %L354

L288:                                             ; preds = %L264
  %199 = fcmp ult double %189, 0x10000000000000
  %200 = fcmp ugt double %189, 0x7FEFFFFFFFFFFFFF
  %201 = or i1 %199, %200
  br i1 %201, label %L323, label %L299

L299:                                             ; preds = %L288
  %202 = fneg double %189
  %.inv = fcmp ogt double %128, %202
  %203 = select i1 %.inv, double %128, double %202
  %.inv182 = fcmp olt double %203, %189
  %204 = select i1 %.inv182, double %203, double %189
  %205 = fsub double %128, %204
  %206 = fadd double %205, 0.000000e+00
  br label %L360

L323:                                             ; preds = %L288
  %207 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 5
  store {}* %getfield, {}** %207, align 8
  %208 = call double @j__exceptional_product_1316(double %188, double %123, double 1.000000e+00)
  %209 = fsub double %128, %208
  %bitcast_coercion = bitcast double %209 to i64
  %210 = icmp sgt i64 %bitcast_coercion, -1
  %211 = select i1 %210, double %209, double 0.000000e+00
  %212 = fcmp ord double %209, 0.000000e+00
  %213 = select i1 %212, double %211, double %209
  %214 = fadd double %128, %208
  %bitcast_coercion121 = bitcast double %214 to i64
  %215 = icmp sgt i64 %bitcast_coercion121, -1
  %216 = fcmp ord double %214, 0.000000e+00
  %217 = and i1 %216, %215
  %218 = select i1 %217, double 0.000000e+00, double %214
  %219 = fadd double %213, %218
  %220 = fcmp ult double %188, 0.000000e+00
  %221 = call double @llvm.fabs.f64(double %123)
  %222 = bitcast double %221 to i64
  %223 = icmp ne i64 %222, 9218868437227405312
  %ifelse_cond125 = or i1 %220, %223
  %224 = select i1 %ifelse_cond125, double %219, double 0.000000e+00
  br label %L360

L354:                                             ; preds = %L264
  store {}* %getfield53, {}** %5, align 16
  store {}* %getfield53, {}** %.fca.0.gep152, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep154, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep156, align 8
  store i64 %107, i64* %.fca.2.gep158, align 8
  store i64 1, i64* %.fca.3.gep160, align 8
  %225 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 5
  store {}* %getfield, {}** %225, align 8
  %226 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 4
  store {}* %getfield72, {}** %226, align 16
  %227 = call double @j__sqrt_cold_1317({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %6, {}* nonnull %getfield72, { double }* nocapture readonly %aggregate_load_box, double %arrayref49, double %value_phi40, i64 signext %value_phi9)
  br label %L360

L356:                                             ; preds = %L148
  store {}* %getfield53, {}** %4, align 8
  store {}* %getfield53, {}** %.fca.0.gep, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep, align 8
  store i64 %107, i64* %.fca.2.gep, align 8
  store i64 1, i64* %.fca.3.gep, align 8
  %228 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 5
  store {}* %getfield, {}** %228, align 8
  %229 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe518, i64 0, i64 4
  store {}* %getfield72, {}** %229, align 16
  %230 = call double @j__sqrt_cold_1317({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %7, {}* nonnull %getfield72, { double }* nocapture readonly %aggregate_load_box, double %arrayref49, double %value_phi40, i64 signext %value_phi9)
  br label %L360

L360:                                             ; preds = %L356, %L354, %L323, %L299, %L184
  %value_phi77 = phi double [ %227, %L354 ], [ %230, %L356 ], [ 0.000000e+00, %L184 ], [ %206, %L299 ], [ %224, %L323 ]
  %231 = fadd double %value_phi8, %value_phi77
  %.not174.not = icmp eq i64 %value_phi9, %arraylen
  %232 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not174.not, label %L372, label %L31

L372:                                             ; preds = %L360, %L17
  %value_phi9.lcssa263274 = phi i64 [ %value_phi9.lcssa263275, %L17 ], [ %arraylen, %L360 ]
  %arraysize55.lcssa248265 = phi i64 [ %arraysize55.lcssa248266, %L17 ], [ %arraysize55, %L360 ]
  %value_phi81 = phi double [ %value_phi4, %L17 ], [ %231, %L360 ]
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
  %233 = load {}*, {}** %10, align 8
  %234 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %233, {}** %234, align 8
  ret double %value_phi84

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %235 = bitcast {}* %getfield16 to double**
  %arrayptr168 = load double*, double** %235, align 8
  %236 = getelementptr inbounds double, double* %arrayptr168, i64 %31
  %arrayref = load double, double* %236, align 8
  %237 = fcmp ord double %arrayref, 0.000000e+00
  %238 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr128 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %238, i64 0, i32 1
  %arraylen129 = load i64, i64* %arraylen_ptr128, align 8
  %.not184 = icmp eq i64 %arraylen129, 0
  br i1 %237, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48172 = load double*, double** %22, align 8
  %239 = getelementptr inbounds double, double* %arrayptr48172, i64 %31
  %arrayref49 = load double, double* %239, align 8
  %getfield51 = load atomic {}*, {}** %14 unordered, align 8
  %240 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %240 unordered, align 8
  %241 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr54 = getelementptr inbounds {}*, {}** %241, i64 3
  %242 = bitcast {}** %arraysize_ptr54 to i64*
  %arraysize55 = load i64, i64* %242, align 8
  %arraysize_ptr60 = getelementptr inbounds {}*, {}** %241, i64 4
  %243 = bitcast {}** %arraysize_ptr60 to i64*
  %arraysize61 = load i64, i64* %243, align 8
  %.not173 = icmp ult i64 %31, %arraysize61
  br i1 %.not173, label %L148, label %L145
}
