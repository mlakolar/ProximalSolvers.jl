; Function Attrs: noinline
define float @julia_pass_2120({}* noundef nonnull align 8 dereferenceable(72) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe512 = alloca [6 x {}*], align 16
  %gcframe512.sub = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 0
  %3 = bitcast [6 x {}*]* %gcframe512 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 48, i1 true)
  %4 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 3
  %5 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 2
  %newstruct59 = alloca { [1 x [1 x i64]], i64 }, align 8
  %aggregate_load_box = alloca { float }, align 8
  %6 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %7 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [6 x {}*]* %gcframe512 to i64*
  store i64 16, i64* %9, align 16
  %10 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe512.sub, {}*** %13, align 8
  %14 = bitcast {}* %0 to {}**
  %15 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %16 = icmp slt i64 %2, 1
  br i1 %16, label %L385, label %L17.preheader

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
  %22 = bitcast {}* %1 to float**
  %memcpy_refined_dst = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct59, i64 0, i32 0, i64 0, i64 0
  %23 = getelementptr inbounds { [1 x [1 x i64]], i64 }, { [1 x [1 x i64]], i64 }* %newstruct59, i64 0, i32 1
  %24 = bitcast {}* %0 to i8*
  %25 = getelementptr inbounds i8, i8* %24, i64 8
  %26 = bitcast i8* %25 to i32*
  %27 = bitcast { float }* %aggregate_load_box to i32*
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
  br i1 %29, label %L385.loopexit, label %L17

L17thread-pre-split:                              ; preds = %L374
  %30 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %28, %L17.preheader ]
  %value_phi9.lcssa263275 = phi i64 [ %value_phi9.lcssa263274, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %arraysize55.lcssa248266 = phi i64 [ %arraysize55.lcssa248265, %L17thread-pre-split ], [ undef, %L17.preheader ]
  %value_phi3 = phi i64 [ %30, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi float [ %value_phi81, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L374, label %L31

L31:                                              ; preds = %L362, %L17
  %value_phi8 = phi float [ %326, %L362 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %327, %L362 ], [ 1, %L17 ]
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
  %36 = bitcast {}* %getfield12 to float**
  %arrayptr27170 = load float*, float** %36, align 8
  %37 = bitcast {}* %getfield14 to float**
  %arrayptr30171 = load float*, float** %37, align 8
  %min.iters.check425 = icmp ult i64 %arraylen129, 8
  br i1 %min.iters.check425, label %scalar.ph424, label %vector.ph426

vector.ph426:                                     ; preds = %L54.lr.ph
  %n.vec428 = and i64 %arraylen129, 9223372036854775800
  %38 = add nsw i64 %n.vec428, -8
  %39 = lshr exact i64 %38, 3
  %40 = add nuw nsw i64 %39, 1
  %xtraiter = and i64 %40, 3
  %41 = icmp ult i64 %38, 24
  br i1 %41, label %middle.block423.unr-lcssa, label %vector.ph426.new

vector.ph426.new:                                 ; preds = %vector.ph426
  %unroll_iter = and i64 %40, 4611686018427387900
  br label %vector.body431

vector.body431:                                   ; preds = %vector.body431, %vector.ph426.new
  %index432 = phi i64 [ 0, %vector.ph426.new ], [ %index.next438.3, %vector.body431 ]
  %vec.phi433 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426.new ], [ %81, %vector.body431 ]
  %vec.phi434 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426.new ], [ %83, %vector.body431 ]
  %vec.phi435 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426.new ], [ %85, %vector.body431 ]
  %niter = phi i64 [ 0, %vector.ph426.new ], [ %niter.next.3, %vector.body431 ]
  %42 = add i64 %35, %index432
  %43 = getelementptr inbounds float, float* %arrayptr27170, i64 %42
  %44 = bitcast float* %43 to <8 x float>*
  %wide.load436 = load <8 x float>, <8 x float>* %44, align 4
  %45 = getelementptr inbounds float, float* %arrayptr30171, i64 %index432
  %46 = bitcast float* %45 to <8 x float>*
  %wide.load437 = load <8 x float>, <8 x float>* %46, align 4
  %47 = fmul contract <8 x float> %wide.load436, %wide.load436
  %48 = fadd reassoc contract <8 x float> %vec.phi433, %47
  %49 = fmul contract <8 x float> %wide.load436, %wide.load437
  %50 = fadd reassoc contract <8 x float> %vec.phi434, %49
  %51 = fmul contract <8 x float> %wide.load437, %wide.load437
  %52 = fadd reassoc contract <8 x float> %vec.phi435, %51
  %index.next438 = or i64 %index432, 8
  %53 = add i64 %35, %index.next438
  %54 = getelementptr inbounds float, float* %arrayptr27170, i64 %53
  %55 = bitcast float* %54 to <8 x float>*
  %wide.load436.1 = load <8 x float>, <8 x float>* %55, align 4
  %56 = getelementptr inbounds float, float* %arrayptr30171, i64 %index.next438
  %57 = bitcast float* %56 to <8 x float>*
  %wide.load437.1 = load <8 x float>, <8 x float>* %57, align 4
  %58 = fmul contract <8 x float> %wide.load436.1, %wide.load436.1
  %59 = fadd reassoc contract <8 x float> %48, %58
  %60 = fmul contract <8 x float> %wide.load436.1, %wide.load437.1
  %61 = fadd reassoc contract <8 x float> %50, %60
  %62 = fmul contract <8 x float> %wide.load437.1, %wide.load437.1
  %63 = fadd reassoc contract <8 x float> %52, %62
  %index.next438.1 = or i64 %index432, 16
  %64 = add i64 %35, %index.next438.1
  %65 = getelementptr inbounds float, float* %arrayptr27170, i64 %64
  %66 = bitcast float* %65 to <8 x float>*
  %wide.load436.2 = load <8 x float>, <8 x float>* %66, align 4
  %67 = getelementptr inbounds float, float* %arrayptr30171, i64 %index.next438.1
  %68 = bitcast float* %67 to <8 x float>*
  %wide.load437.2 = load <8 x float>, <8 x float>* %68, align 4
  %69 = fmul contract <8 x float> %wide.load436.2, %wide.load436.2
  %70 = fadd reassoc contract <8 x float> %59, %69
  %71 = fmul contract <8 x float> %wide.load436.2, %wide.load437.2
  %72 = fadd reassoc contract <8 x float> %61, %71
  %73 = fmul contract <8 x float> %wide.load437.2, %wide.load437.2
  %74 = fadd reassoc contract <8 x float> %63, %73
  %index.next438.2 = or i64 %index432, 24
  %75 = add i64 %35, %index.next438.2
  %76 = getelementptr inbounds float, float* %arrayptr27170, i64 %75
  %77 = bitcast float* %76 to <8 x float>*
  %wide.load436.3 = load <8 x float>, <8 x float>* %77, align 4
  %78 = getelementptr inbounds float, float* %arrayptr30171, i64 %index.next438.2
  %79 = bitcast float* %78 to <8 x float>*
  %wide.load437.3 = load <8 x float>, <8 x float>* %79, align 4
  %80 = fmul contract <8 x float> %wide.load436.3, %wide.load436.3
  %81 = fadd reassoc contract <8 x float> %70, %80
  %82 = fmul contract <8 x float> %wide.load436.3, %wide.load437.3
  %83 = fadd reassoc contract <8 x float> %72, %82
  %84 = fmul contract <8 x float> %wide.load437.3, %wide.load437.3
  %85 = fadd reassoc contract <8 x float> %74, %84
  %index.next438.3 = add nuw i64 %index432, 32
  %niter.next.3 = add i64 %niter, 4
  %niter.ncmp.3 = icmp eq i64 %niter.next.3, %unroll_iter
  br i1 %niter.ncmp.3, label %middle.block423.unr-lcssa, label %vector.body431

middle.block423.unr-lcssa:                        ; preds = %vector.body431, %vector.ph426
  %.lcssa445.ph = phi <8 x float> [ undef, %vector.ph426 ], [ %81, %vector.body431 ]
  %.lcssa444.ph = phi <8 x float> [ undef, %vector.ph426 ], [ %83, %vector.body431 ]
  %.lcssa.ph = phi <8 x float> [ undef, %vector.ph426 ], [ %85, %vector.body431 ]
  %index432.unr = phi i64 [ 0, %vector.ph426 ], [ %index.next438.3, %vector.body431 ]
  %vec.phi433.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426 ], [ %81, %vector.body431 ]
  %vec.phi434.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426 ], [ %83, %vector.body431 ]
  %vec.phi435.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426 ], [ %85, %vector.body431 ]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %middle.block423, label %vector.body431.epil

vector.body431.epil:                              ; preds = %vector.body431.epil, %middle.block423.unr-lcssa
  %index432.epil = phi i64 [ %index.next438.epil, %vector.body431.epil ], [ %index432.unr, %middle.block423.unr-lcssa ]
  %vec.phi433.epil = phi <8 x float> [ %92, %vector.body431.epil ], [ %vec.phi433.unr, %middle.block423.unr-lcssa ]
  %vec.phi434.epil = phi <8 x float> [ %94, %vector.body431.epil ], [ %vec.phi434.unr, %middle.block423.unr-lcssa ]
  %vec.phi435.epil = phi <8 x float> [ %96, %vector.body431.epil ], [ %vec.phi435.unr, %middle.block423.unr-lcssa ]
  %epil.iter = phi i64 [ %epil.iter.next, %vector.body431.epil ], [ 0, %middle.block423.unr-lcssa ]
  %86 = add i64 %35, %index432.epil
  %87 = getelementptr inbounds float, float* %arrayptr27170, i64 %86
  %88 = bitcast float* %87 to <8 x float>*
  %wide.load436.epil = load <8 x float>, <8 x float>* %88, align 4
  %89 = getelementptr inbounds float, float* %arrayptr30171, i64 %index432.epil
  %90 = bitcast float* %89 to <8 x float>*
  %wide.load437.epil = load <8 x float>, <8 x float>* %90, align 4
  %91 = fmul contract <8 x float> %wide.load436.epil, %wide.load436.epil
  %92 = fadd reassoc contract <8 x float> %vec.phi433.epil, %91
  %93 = fmul contract <8 x float> %wide.load436.epil, %wide.load437.epil
  %94 = fadd reassoc contract <8 x float> %vec.phi434.epil, %93
  %95 = fmul contract <8 x float> %wide.load437.epil, %wide.load437.epil
  %96 = fadd reassoc contract <8 x float> %vec.phi435.epil, %95
  %index.next438.epil = add nuw i64 %index432.epil, 8
  %epil.iter.next = add i64 %epil.iter, 1
  %epil.iter.cmp.not = icmp eq i64 %epil.iter.next, %xtraiter
  br i1 %epil.iter.cmp.not, label %middle.block423, label %vector.body431.epil

middle.block423:                                  ; preds = %vector.body431.epil, %middle.block423.unr-lcssa
  %.lcssa445 = phi <8 x float> [ %.lcssa445.ph, %middle.block423.unr-lcssa ], [ %92, %vector.body431.epil ]
  %.lcssa444 = phi <8 x float> [ %.lcssa444.ph, %middle.block423.unr-lcssa ], [ %94, %vector.body431.epil ]
  %.lcssa = phi <8 x float> [ %.lcssa.ph, %middle.block423.unr-lcssa ], [ %96, %vector.body431.epil ]
  %97 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa)
  %98 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa444)
  %99 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa445)
  %cmp.n430 = icmp eq i64 %arraylen129, %n.vec428
  br i1 %cmp.n430, label %L124, label %scalar.ph424

scalar.ph424:                                     ; preds = %middle.block423, %L54.lr.ph
  %bc.resume.val429 = phi i64 [ %n.vec428, %middle.block423 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx439 = phi float [ %99, %middle.block423 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx440 = phi float [ %98, %middle.block423 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx441 = phi float [ %97, %middle.block423 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph424
  %value_phi25223 = phi float [ %bc.merge.rdx439, %scalar.ph424 ], [ %104, %L54 ]
  %value_phi24222 = phi i64 [ %bc.resume.val429, %scalar.ph424 ], [ %109, %L54 ]
  %value_phi23221 = phi float [ %bc.merge.rdx440, %scalar.ph424 ], [ %106, %L54 ]
  %value_phi22220 = phi float [ %bc.merge.rdx441, %scalar.ph424 ], [ %108, %L54 ]
  %100 = add i64 %35, %value_phi24222
  %101 = getelementptr inbounds float, float* %arrayptr27170, i64 %100
  %arrayref28 = load float, float* %101, align 4
  %102 = getelementptr inbounds float, float* %arrayptr30171, i64 %value_phi24222
  %arrayref31 = load float, float* %102, align 4
  %103 = fmul contract float %arrayref28, %arrayref28
  %104 = fadd reassoc contract float %value_phi25223, %103
  %105 = fmul contract float %arrayref28, %arrayref31
  %106 = fadd reassoc contract float %value_phi23221, %105
  %107 = fmul contract float %arrayref31, %arrayref31
  %108 = fadd reassoc contract float %value_phi22220, %107
  %109 = add nuw nsw i64 %value_phi24222, 1
  %exitcond.not = icmp eq i64 %109, %arraylen129
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not184, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %110 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr135 = getelementptr inbounds {}*, {}** %110, i64 3
  %111 = bitcast {}** %arraysize_ptr135 to i64*
  %arraysize136 = load i64, i64* %111, align 8
  %112 = mul i64 %arraysize136, %31
  %113 = bitcast {}* %getfield12 to float**
  %arrayptr139186 = load float*, float** %113, align 8
  %114 = bitcast {}* %getfield14 to float**
  %arrayptr142187 = load float*, float** %114, align 8
  %min.iters.check402 = icmp ult i64 %arraylen129, 16
  br i1 %min.iters.check402, label %scalar.ph401, label %vector.ph403

vector.ph403:                                     ; preds = %L96.lr.ph
  %n.vec405 = and i64 %arraylen129, 9223372036854775792
  %115 = add nsw i64 %n.vec405, -16
  %116 = lshr exact i64 %115, 4
  %117 = add nuw nsw i64 %116, 1
  %xtraiter495 = and i64 %117, 1
  %118 = icmp eq i64 %115, 0
  br i1 %118, label %middle.block400.unr-lcssa, label %vector.ph403.new

vector.ph403.new:                                 ; preds = %vector.ph403
  %unroll_iter502 = and i64 %117, 2305843009213693950
  br label %vector.body408

vector.body408:                                   ; preds = %vector.body408, %vector.ph403.new
  %index409 = phi i64 [ 0, %vector.ph403.new ], [ %index.next418.1, %vector.body408 ]
  %vec.phi410 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403.new ], [ %147, %vector.body408 ]
  %vec.phi411 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403.new ], [ %148, %vector.body408 ]
  %vec.phi412 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403.new ], [ %151, %vector.body408 ]
  %vec.phi413 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403.new ], [ %152, %vector.body408 ]
  %niter503 = phi i64 [ 0, %vector.ph403.new ], [ %niter503.next.1, %vector.body408 ]
  %119 = add i64 %112, %index409
  %120 = getelementptr inbounds float, float* %arrayptr139186, i64 %119
  %121 = bitcast float* %120 to <8 x float>*
  %wide.load414 = load <8 x float>, <8 x float>* %121, align 4
  %122 = getelementptr inbounds float, float* %120, i64 8
  %123 = bitcast float* %122 to <8 x float>*
  %wide.load415 = load <8 x float>, <8 x float>* %123, align 4
  %124 = getelementptr inbounds float, float* %arrayptr142187, i64 %index409
  %125 = bitcast float* %124 to <8 x float>*
  %wide.load416 = load <8 x float>, <8 x float>* %125, align 4
  %126 = getelementptr inbounds float, float* %124, i64 8
  %127 = bitcast float* %126 to <8 x float>*
  %wide.load417 = load <8 x float>, <8 x float>* %127, align 4
  %128 = fmul contract <8 x float> %wide.load414, %wide.load416
  %129 = fmul contract <8 x float> %wide.load415, %wide.load417
  %130 = fadd reassoc contract <8 x float> %vec.phi410, %128
  %131 = fadd reassoc contract <8 x float> %vec.phi411, %129
  %132 = fmul contract <8 x float> %wide.load416, %wide.load416
  %133 = fmul contract <8 x float> %wide.load417, %wide.load417
  %134 = fadd reassoc contract <8 x float> %vec.phi412, %132
  %135 = fadd reassoc contract <8 x float> %vec.phi413, %133
  %index.next418 = or i64 %index409, 16
  %136 = add i64 %112, %index.next418
  %137 = getelementptr inbounds float, float* %arrayptr139186, i64 %136
  %138 = bitcast float* %137 to <8 x float>*
  %wide.load414.1 = load <8 x float>, <8 x float>* %138, align 4
  %139 = getelementptr inbounds float, float* %137, i64 8
  %140 = bitcast float* %139 to <8 x float>*
  %wide.load415.1 = load <8 x float>, <8 x float>* %140, align 4
  %141 = getelementptr inbounds float, float* %arrayptr142187, i64 %index.next418
  %142 = bitcast float* %141 to <8 x float>*
  %wide.load416.1 = load <8 x float>, <8 x float>* %142, align 4
  %143 = getelementptr inbounds float, float* %141, i64 8
  %144 = bitcast float* %143 to <8 x float>*
  %wide.load417.1 = load <8 x float>, <8 x float>* %144, align 4
  %145 = fmul contract <8 x float> %wide.load414.1, %wide.load416.1
  %146 = fmul contract <8 x float> %wide.load415.1, %wide.load417.1
  %147 = fadd reassoc contract <8 x float> %130, %145
  %148 = fadd reassoc contract <8 x float> %131, %146
  %149 = fmul contract <8 x float> %wide.load416.1, %wide.load416.1
  %150 = fmul contract <8 x float> %wide.load417.1, %wide.load417.1
  %151 = fadd reassoc contract <8 x float> %134, %149
  %152 = fadd reassoc contract <8 x float> %135, %150
  %index.next418.1 = add nuw i64 %index409, 32
  %niter503.next.1 = add i64 %niter503, 2
  %niter503.ncmp.1 = icmp eq i64 %niter503.next.1, %unroll_iter502
  br i1 %niter503.ncmp.1, label %middle.block400.unr-lcssa, label %vector.body408

middle.block400.unr-lcssa:                        ; preds = %vector.body408, %vector.ph403
  %.lcssa452.ph = phi <8 x float> [ undef, %vector.ph403 ], [ %147, %vector.body408 ]
  %.lcssa451.ph = phi <8 x float> [ undef, %vector.ph403 ], [ %148, %vector.body408 ]
  %.lcssa450.ph = phi <8 x float> [ undef, %vector.ph403 ], [ %151, %vector.body408 ]
  %.lcssa449.ph = phi <8 x float> [ undef, %vector.ph403 ], [ %152, %vector.body408 ]
  %index409.unr = phi i64 [ 0, %vector.ph403 ], [ %index.next418.1, %vector.body408 ]
  %vec.phi410.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %147, %vector.body408 ]
  %vec.phi411.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %148, %vector.body408 ]
  %vec.phi412.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %151, %vector.body408 ]
  %vec.phi413.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %152, %vector.body408 ]
  %lcmp.mod497.not = icmp eq i64 %xtraiter495, 0
  br i1 %lcmp.mod497.not, label %middle.block400, label %vector.body408.epil.preheader

vector.body408.epil.preheader:                    ; preds = %middle.block400.unr-lcssa
  %153 = add i64 %112, %index409.unr
  %154 = getelementptr inbounds float, float* %arrayptr139186, i64 %153
  %155 = bitcast float* %154 to <8 x float>*
  %wide.load414.epil = load <8 x float>, <8 x float>* %155, align 4
  %156 = getelementptr inbounds float, float* %154, i64 8
  %157 = bitcast float* %156 to <8 x float>*
  %wide.load415.epil = load <8 x float>, <8 x float>* %157, align 4
  %158 = getelementptr inbounds float, float* %arrayptr142187, i64 %index409.unr
  %159 = bitcast float* %158 to <8 x float>*
  %wide.load416.epil = load <8 x float>, <8 x float>* %159, align 4
  %160 = getelementptr inbounds float, float* %158, i64 8
  %161 = bitcast float* %160 to <8 x float>*
  %wide.load417.epil = load <8 x float>, <8 x float>* %161, align 4
  %162 = fmul contract <8 x float> %wide.load414.epil, %wide.load416.epil
  %163 = fmul contract <8 x float> %wide.load415.epil, %wide.load417.epil
  %164 = fadd reassoc contract <8 x float> %vec.phi410.unr, %162
  %165 = fadd reassoc contract <8 x float> %vec.phi411.unr, %163
  %166 = fmul contract <8 x float> %wide.load416.epil, %wide.load416.epil
  %167 = fmul contract <8 x float> %wide.load417.epil, %wide.load417.epil
  %168 = fadd reassoc contract <8 x float> %vec.phi412.unr, %166
  %169 = fadd reassoc contract <8 x float> %vec.phi413.unr, %167
  br label %middle.block400

middle.block400:                                  ; preds = %vector.body408.epil.preheader, %middle.block400.unr-lcssa
  %.lcssa452 = phi <8 x float> [ %.lcssa452.ph, %middle.block400.unr-lcssa ], [ %164, %vector.body408.epil.preheader ]
  %.lcssa451 = phi <8 x float> [ %.lcssa451.ph, %middle.block400.unr-lcssa ], [ %165, %vector.body408.epil.preheader ]
  %.lcssa450 = phi <8 x float> [ %.lcssa450.ph, %middle.block400.unr-lcssa ], [ %168, %vector.body408.epil.preheader ]
  %.lcssa449 = phi <8 x float> [ %.lcssa449.ph, %middle.block400.unr-lcssa ], [ %169, %vector.body408.epil.preheader ]
  %bin.rdx421 = fadd reassoc contract <8 x float> %.lcssa449, %.lcssa450
  %170 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx421)
  %bin.rdx419 = fadd reassoc contract <8 x float> %.lcssa451, %.lcssa452
  %171 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx419)
  %cmp.n407 = icmp eq i64 %arraylen129, %n.vec405
  br i1 %cmp.n407, label %L124, label %scalar.ph401

scalar.ph401:                                     ; preds = %middle.block400, %L96.lr.ph
  %bc.resume.val406 = phi i64 [ %n.vec405, %middle.block400 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx420 = phi float [ %171, %middle.block400 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx422 = phi float [ %170, %middle.block400 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph401
  %value_phi134229 = phi i64 [ %bc.resume.val406, %scalar.ph401 ], [ %179, %L96 ]
  %value_phi133228 = phi float [ %bc.merge.rdx420, %scalar.ph401 ], [ %176, %L96 ]
  %value_phi132227 = phi float [ %bc.merge.rdx422, %scalar.ph401 ], [ %178, %L96 ]
  %172 = add i64 %112, %value_phi134229
  %173 = getelementptr inbounds float, float* %arrayptr139186, i64 %172
  %arrayref140 = load float, float* %173, align 4
  %174 = getelementptr inbounds float, float* %arrayptr142187, i64 %value_phi134229
  %arrayref143 = load float, float* %174, align 4
  %175 = fmul contract float %arrayref140, %arrayref143
  %176 = fadd reassoc contract float %value_phi133228, %175
  %177 = fmul contract float %arrayref143, %arrayref143
  %178 = fadd reassoc contract float %value_phi132227, %177
  %179 = add nuw nsw i64 %value_phi134229, 1
  %exitcond284.not = icmp eq i64 %179, %arraylen129
  br i1 %exitcond284.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block400, %L83, %L54, %middle.block423, %L40
  %value_phi38 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %170, %middle.block400 ], [ %97, %middle.block423 ], [ %178, %L96 ], [ %108, %L54 ]
  %value_phi39 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %171, %middle.block400 ], [ %98, %middle.block423 ], [ %176, %L96 ], [ %106, %L54 ]
  %value_phi40 = phi float [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block400 ], [ %99, %middle.block423 ], [ %arrayref, %L96 ], [ %104, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %31, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L145:                                             ; preds = %idxend46
  store i64 %arraysize55, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %23, align 8
  %180 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 4
  store {}* %getfield53, {}** %180, align 16
  call void @j_throw_boundserror_2127({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct59) #2
  unreachable

L148:                                             ; preds = %idxend46
  %181 = mul i64 %arraysize55, %31
  %182 = bitcast {}* %getfield51 to i8*
  %getfield_addr71 = getelementptr inbounds i8, i8* %182, i64 24
  %183 = bitcast i8* %getfield_addr71 to {}**
  %getfield72 = load atomic {}*, {}** %183 unordered, align 8
  %184 = load i32, i32* %26, align 1
  store i32 %184, i32* %27, align 8
  %185 = bitcast {}* %getfield72 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr73 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %185, i64 0, i32 1
  %arraylen74 = load i64, i64* %arraylen_ptr73, align 8
  %186 = fsub float %value_phi40, %value_phi40
  %187 = fcmp ord float %186, 0.000000e+00
  %188 = sitofp i64 %arraylen74 to float
  %189 = fmul float %188, 0x3980000000000000
  %190 = fcmp ole float %189, %value_phi40
  %191 = and i1 %187, %190
  %192 = fsub float %value_phi38, %value_phi38
  %193 = fcmp ord float %192, 0.000000e+00
  %194 = fcmp ole float %189, %value_phi38
  %195 = and i1 %193, %194
  %196 = and i1 %191, %195
  %197 = bitcast i32 %184 to float
  br i1 %196, label %L179, label %L358

L179:                                             ; preds = %L148
  %198 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %198, label %L184, label %L182

L182:                                             ; preds = %L179
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 140312453360144 to {}*), float %value_phi40) #2
  unreachable

L184:                                             ; preds = %L179
  %199 = call float @llvm.sqrt.f32(float %value_phi40)
  %200 = fcmp ugt float %199, %197
  br i1 %200, label %L189, label %L362

L189:                                             ; preds = %L184
  %201 = fdiv float %value_phi39, %value_phi40
  %202 = fadd float %201, %arrayref49
  %203 = fmul float %value_phi39, %201
  %204 = fsub float %value_phi38, %203
  %205 = fmul float %value_phi38, 6.250000e-02
  %206 = fcmp uge float %204, %205
  br i1 %206, label %L245, label %L196

L196:                                             ; preds = %L189
  %.not176 = icmp eq i64 %arraylen74, 0
  br i1 %.not176, label %L250, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L196
  %207 = bitcast {}* %getfield72 to float**
  %arrayptr92178 = load float*, float** %207, align 8
  %208 = bitcast {}* %getfield53 to float**
  %arrayptr96179 = load float*, float** %208, align 8
  %min.iters.check = icmp ult i64 %arraylen74, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen74, 9223372036854775792
  %broadcast.splatinsert = insertelement <8 x float> poison, float %201, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  %209 = add nsw i64 %n.vec, -16
  %210 = lshr exact i64 %209, 4
  %211 = add nuw nsw i64 %210, 1
  %xtraiter504 = and i64 %211, 1
  %212 = icmp eq i64 %209, 0
  br i1 %212, label %middle.block.unr-lcssa, label %vector.ph.new

vector.ph.new:                                    ; preds = %vector.ph
  %unroll_iter509 = and i64 %211, 2305843009213693950
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph.new
  %index = phi i64 [ 0, %vector.ph.new ], [ %index.next.1, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph.new ], [ %245, %vector.body ]
  %vec.phi394 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph.new ], [ %246, %vector.body ]
  %niter510 = phi i64 [ 0, %vector.ph.new ], [ %niter510.next.1, %vector.body ]
  %213 = getelementptr inbounds float, float* %arrayptr92178, i64 %index
  %214 = bitcast float* %213 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %214, align 4
  %215 = getelementptr inbounds float, float* %213, i64 8
  %216 = bitcast float* %215 to <8 x float>*
  %wide.load395 = load <8 x float>, <8 x float>* %216, align 4
  %217 = add i64 %index, %181
  %218 = getelementptr inbounds float, float* %arrayptr96179, i64 %217
  %219 = bitcast float* %218 to <8 x float>*
  %wide.load396 = load <8 x float>, <8 x float>* %219, align 4
  %220 = getelementptr inbounds float, float* %218, i64 8
  %221 = bitcast float* %220 to <8 x float>*
  %wide.load397 = load <8 x float>, <8 x float>* %221, align 4
  %222 = fmul <8 x float> %broadcast.splat, %wide.load396
  %223 = fmul <8 x float> %broadcast.splat, %wide.load397
  %224 = fsub <8 x float> %wide.load, %222
  %225 = fsub <8 x float> %wide.load395, %223
  %226 = fmul contract <8 x float> %224, %224
  %227 = fmul contract <8 x float> %225, %225
  %228 = fadd reassoc contract <8 x float> %vec.phi, %226
  %229 = fadd reassoc contract <8 x float> %vec.phi394, %227
  %index.next = or i64 %index, 16
  %230 = getelementptr inbounds float, float* %arrayptr92178, i64 %index.next
  %231 = bitcast float* %230 to <8 x float>*
  %wide.load.1 = load <8 x float>, <8 x float>* %231, align 4
  %232 = getelementptr inbounds float, float* %230, i64 8
  %233 = bitcast float* %232 to <8 x float>*
  %wide.load395.1 = load <8 x float>, <8 x float>* %233, align 4
  %234 = add i64 %index.next, %181
  %235 = getelementptr inbounds float, float* %arrayptr96179, i64 %234
  %236 = bitcast float* %235 to <8 x float>*
  %wide.load396.1 = load <8 x float>, <8 x float>* %236, align 4
  %237 = getelementptr inbounds float, float* %235, i64 8
  %238 = bitcast float* %237 to <8 x float>*
  %wide.load397.1 = load <8 x float>, <8 x float>* %238, align 4
  %239 = fmul <8 x float> %broadcast.splat, %wide.load396.1
  %240 = fmul <8 x float> %broadcast.splat, %wide.load397.1
  %241 = fsub <8 x float> %wide.load.1, %239
  %242 = fsub <8 x float> %wide.load395.1, %240
  %243 = fmul contract <8 x float> %241, %241
  %244 = fmul contract <8 x float> %242, %242
  %245 = fadd reassoc contract <8 x float> %228, %243
  %246 = fadd reassoc contract <8 x float> %229, %244
  %index.next.1 = add nuw i64 %index, 32
  %niter510.next.1 = add i64 %niter510, 2
  %niter510.ncmp.1 = icmp eq i64 %niter510.next.1, %unroll_iter509
  br i1 %niter510.ncmp.1, label %middle.block.unr-lcssa, label %vector.body

middle.block.unr-lcssa:                           ; preds = %vector.body, %vector.ph
  %.lcssa456.ph = phi <8 x float> [ undef, %vector.ph ], [ %245, %vector.body ]
  %.lcssa455.ph = phi <8 x float> [ undef, %vector.ph ], [ %246, %vector.body ]
  %index.unr = phi i64 [ 0, %vector.ph ], [ %index.next.1, %vector.body ]
  %vec.phi.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %245, %vector.body ]
  %vec.phi394.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %246, %vector.body ]
  %lcmp.mod506.not = icmp eq i64 %xtraiter504, 0
  br i1 %lcmp.mod506.not, label %middle.block, label %vector.body.epil.preheader

vector.body.epil.preheader:                       ; preds = %middle.block.unr-lcssa
  %247 = getelementptr inbounds float, float* %arrayptr92178, i64 %index.unr
  %248 = bitcast float* %247 to <8 x float>*
  %wide.load.epil = load <8 x float>, <8 x float>* %248, align 4
  %249 = getelementptr inbounds float, float* %247, i64 8
  %250 = bitcast float* %249 to <8 x float>*
  %wide.load395.epil = load <8 x float>, <8 x float>* %250, align 4
  %251 = add i64 %index.unr, %181
  %252 = getelementptr inbounds float, float* %arrayptr96179, i64 %251
  %253 = bitcast float* %252 to <8 x float>*
  %wide.load396.epil = load <8 x float>, <8 x float>* %253, align 4
  %254 = getelementptr inbounds float, float* %252, i64 8
  %255 = bitcast float* %254 to <8 x float>*
  %wide.load397.epil = load <8 x float>, <8 x float>* %255, align 4
  %256 = fmul <8 x float> %broadcast.splat, %wide.load396.epil
  %257 = fmul <8 x float> %broadcast.splat, %wide.load397.epil
  %258 = fsub <8 x float> %wide.load.epil, %256
  %259 = fsub <8 x float> %wide.load395.epil, %257
  %260 = fmul contract <8 x float> %258, %258
  %261 = fmul contract <8 x float> %259, %259
  %262 = fadd reassoc contract <8 x float> %vec.phi.unr, %260
  %263 = fadd reassoc contract <8 x float> %vec.phi394.unr, %261
  br label %middle.block

middle.block:                                     ; preds = %vector.body.epil.preheader, %middle.block.unr-lcssa
  %.lcssa456 = phi <8 x float> [ %.lcssa456.ph, %middle.block.unr-lcssa ], [ %262, %vector.body.epil.preheader ]
  %.lcssa455 = phi <8 x float> [ %.lcssa455.ph, %middle.block.unr-lcssa ], [ %263, %vector.body.epil.preheader ]
  %bin.rdx = fadd reassoc contract <8 x float> %.lcssa455, %.lcssa456
  %264 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n = icmp eq i64 %arraylen74, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi float [ %264, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90234 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %272, %L208 ]
  %value_phi89233 = phi float [ %bc.merge.rdx, %scalar.ph ], [ %271, %L208 ]
  %265 = getelementptr inbounds float, float* %arrayptr92178, i64 %value_phi90234
  %arrayref93 = load float, float* %265, align 4
  %266 = add i64 %value_phi90234, %181
  %267 = getelementptr inbounds float, float* %arrayptr96179, i64 %266
  %arrayref97 = load float, float* %267, align 4
  %268 = fmul float %201, %arrayref97
  %269 = fsub float %arrayref93, %268
  %270 = fmul contract float %269, %269
  %271 = fadd reassoc contract float %value_phi89233, %270
  %272 = add nuw nsw i64 %value_phi90234, 1
  %exitcond285.not = icmp eq i64 %272, %arraylen74
  br i1 %exitcond285.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L189
  %value_phi102 = phi float [ %204, %L189 ], [ %264, %middle.block ], [ %271, %L208 ]
  %273 = fcmp uge float %value_phi102, 0.000000e+00
  br i1 %273, label %L250, label %L248

L248:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 140312453360144 to {}*), float %value_phi102) #2
  unreachable

L250:                                             ; preds = %L245, %L196
  %value_phi102189 = phi float [ %value_phi102, %L245 ], [ 0.000000e+00, %L196 ]
  %274 = call float @llvm.sqrt.f32(float %value_phi102189)
  %275 = fsub float %199, %197
  %276 = fcmp uge float %275, 0.000000e+00
  br i1 %276, label %L257, label %L255

L255:                                             ; preds = %L250
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 140312453360144 to {}*), float %275) #2
  unreachable

L257:                                             ; preds = %L250
  %277 = fadd float %199, %197
  %278 = fcmp uge float %277, 0.000000e+00
  br i1 %278, label %L264, label %L262

L262:                                             ; preds = %L257
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 140312453360144 to {}*), float %277) #2
  unreachable

L264:                                             ; preds = %L257
  %279 = call float @llvm.sqrt.f32(float %275)
  %280 = call float @llvm.sqrt.f32(float %277)
  %281 = fmul float %279, %280
  %282 = fmul float %199, %281
  %283 = fdiv float %274, %282
  %284 = fmul float %283, %197
  %285 = fcmp oge float %282, 0x3810000000000000
  %286 = fcmp oeq float %274, 0.000000e+00
  %287 = fcmp oge float %283, 0x3810000000000000
  %288 = fcmp ole float %283, 0x47EFFFFFE0000000
  %narrow = and i1 %287, %288
  %289 = fcmp oge float %284, 0x3810000000000000
  %290 = fcmp ole float %284, 0x47EFFFFFE0000000
  %narrow180 = and i1 %289, %290
  %291 = and i1 %narrow, %narrow180
  %292 = or i1 %286, %291
  %293 = and i1 %285, %292
  br i1 %293, label %L288, label %L356

L288:                                             ; preds = %L264
  %294 = fcmp ult float %284, 0x3810000000000000
  %295 = fcmp ugt float %284, 0x47EFFFFFE0000000
  %296 = or i1 %294, %295
  br i1 %296, label %L323, label %L299

L299:                                             ; preds = %L288
  %297 = fneg float %284
  %.inv = fcmp ogt float %202, %297
  %298 = select i1 %.inv, float %202, float %297
  %.inv182 = fcmp olt float %298, %284
  %299 = select i1 %.inv182, float %298, float %284
  %300 = fsub float %202, %299
  %301 = fadd float %300, 0.000000e+00
  br label %L362

L323:                                             ; preds = %L288
  %302 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 5
  store {}* %getfield, {}** %302, align 8
  %303 = call float @j__exceptional_product_2125(float %283, float %197, float 1.000000e+00)
  %304 = fsub float %202, %303
  %bitcast_coercion = bitcast float %304 to i32
  %305 = icmp sgt i32 %bitcast_coercion, -1
  %306 = select i1 %305, float %304, float 0.000000e+00
  %307 = fcmp ord float %304, 0.000000e+00
  %308 = select i1 %307, float %306, float %304
  %309 = fadd float %202, %303
  %bitcast_coercion121 = bitcast float %309 to i32
  %310 = icmp sgt i32 %bitcast_coercion121, -1
  %311 = fcmp ord float %309, 0.000000e+00
  %312 = and i1 %311, %310
  %313 = select i1 %312, float 0.000000e+00, float %309
  %314 = fadd float %308, %313
  %315 = fcmp ult float %283, 0.000000e+00
  %316 = call float @llvm.fabs.f32(float %197)
  %317 = bitcast float %316 to i32
  %318 = icmp ne i32 %317, 2139095040
  %ifelse_cond125 = or i1 %315, %318
  %319 = select i1 %ifelse_cond125, float %314, float 0.000000e+00
  br label %L362

L356:                                             ; preds = %L264
  store {}* %getfield53, {}** %5, align 16
  store {}* %getfield53, {}** %.fca.0.gep152, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep154, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep156, align 8
  store i64 %181, i64* %.fca.2.gep158, align 8
  store i64 1, i64* %.fca.3.gep160, align 8
  %320 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 5
  store {}* %getfield, {}** %320, align 8
  %321 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 4
  store {}* %getfield72, {}** %321, align 16
  %322 = call float @j__sqrt_cold_2126({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %6, {}* nonnull %getfield72, { float }* nocapture readonly %aggregate_load_box, float %arrayref49, float %value_phi40, i64 signext %value_phi9)
  br label %L362

L358:                                             ; preds = %L148
  store {}* %getfield53, {}** %4, align 8
  store {}* %getfield53, {}** %.fca.0.gep, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep, align 8
  store i64 %181, i64* %.fca.2.gep, align 8
  store i64 1, i64* %.fca.3.gep, align 8
  %323 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 5
  store {}* %getfield, {}** %323, align 8
  %324 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe512, i64 0, i64 4
  store {}* %getfield72, {}** %324, align 16
  %325 = call float @j__sqrt_cold_2126({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %7, {}* nonnull %getfield72, { float }* nocapture readonly %aggregate_load_box, float %arrayref49, float %value_phi40, i64 signext %value_phi9)
  br label %L362

L362:                                             ; preds = %L358, %L356, %L323, %L299, %L184
  %value_phi77 = phi float [ %322, %L356 ], [ %325, %L358 ], [ 0.000000e+00, %L184 ], [ %301, %L299 ], [ %319, %L323 ]
  %326 = fadd float %value_phi8, %value_phi77
  %.not174.not = icmp eq i64 %value_phi9, %arraylen
  %327 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not174.not, label %L374, label %L31

L374:                                             ; preds = %L362, %L17
  %value_phi9.lcssa263274 = phi i64 [ %value_phi9.lcssa263275, %L17 ], [ %arraylen, %L362 ]
  %arraysize55.lcssa248265 = phi i64 [ %arraysize55.lcssa248266, %L17 ], [ %arraysize55, %L362 ]
  %value_phi81 = phi float [ %value_phi4, %L17 ], [ %326, %L362 ]
  %.not175 = icmp eq i64 %value_phi3, %15
  br i1 %.not175, label %L385.loopexit, label %L17thread-pre-split

L385.loopexit:                                    ; preds = %L374, %L17.preheader
  %.us-phi = phi i64 [ undef, %L17.preheader ], [ %value_phi9.lcssa263274, %L374 ]
  %.us-phi282 = phi i64 [ undef, %L17.preheader ], [ %arraysize55.lcssa248265, %L374 ]
  %.us-phi283 = phi float [ 0.000000e+00, %L17.preheader ], [ %value_phi81, %L374 ]
  store i64 %.us-phi282, i64* %memcpy_refined_dst, align 8
  store i64 %.us-phi, i64* %23, align 8
  br label %L385

L385:                                             ; preds = %L385.loopexit, %top
  %value_phi84 = phi float [ 0.000000e+00, %top ], [ %.us-phi283, %L385.loopexit ]
  %328 = load {}*, {}** %10, align 8
  %329 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %328, {}** %329, align 8
  ret float %value_phi84

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %330 = bitcast {}* %getfield16 to float**
  %arrayptr168 = load float*, float** %330, align 8
  %331 = getelementptr inbounds float, float* %arrayptr168, i64 %31
  %arrayref = load float, float* %331, align 4
  %332 = fcmp ord float %arrayref, 0.000000e+00
  %333 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr128 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %333, i64 0, i32 1
  %arraylen129 = load i64, i64* %arraylen_ptr128, align 8
  %.not184 = icmp eq i64 %arraylen129, 0
  br i1 %332, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48172 = load float*, float** %22, align 8
  %334 = getelementptr inbounds float, float* %arrayptr48172, i64 %31
  %arrayref49 = load float, float* %334, align 4
  %getfield51 = load atomic {}*, {}** %14 unordered, align 8
  %335 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %335 unordered, align 8
  %336 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr54 = getelementptr inbounds {}*, {}** %336, i64 3
  %337 = bitcast {}** %arraysize_ptr54 to i64*
  %arraysize55 = load i64, i64* %337, align 8
  %arraysize_ptr60 = getelementptr inbounds {}*, {}** %336, i64 4
  %338 = bitcast {}** %arraysize_ptr60 to i64*
  %arraysize61 = load i64, i64* %338, align 8
  %.not173 = icmp ult i64 %31, %arraysize61
  br i1 %.not173, label %L148, label %L145
}
