; Function Attrs: noinline
define float @julia_pass_1651({}* noundef nonnull align 8 dereferenceable(72) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe369 = alloca [3 x {}*], align 16
  %gcframe369.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe369, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe369 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe369 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe369, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe369.sub, {}*** %9, align 8
  %10 = bitcast {}* %0 to {}**
  %11 = call i64 @llvm.smax.i64(i64 %2, i64 0)
  %12 = icmp slt i64 %2, 1
  br i1 %12, label %L349, label %L17.preheader

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
  %21 = load i64, i64* %arraylen_ptr, align 8
  %22 = icmp eq i64 %21, 0
  br i1 %22, label %L349, label %L17

L17thread-pre-split:                              ; preds = %L338
  %23 = add nuw i64 %value_phi3, 1
  %arraylen.pr = load i64, i64* %arraylen_ptr, align 8
  br label %L17

L17:                                              ; preds = %L17thread-pre-split, %L17.preheader
  %arraylen = phi i64 [ %arraylen.pr, %L17thread-pre-split ], [ %21, %L17.preheader ]
  %value_phi3 = phi i64 [ %23, %L17thread-pre-split ], [ 1, %L17.preheader ]
  %value_phi4 = phi float [ %value_phi61, %L17thread-pre-split ], [ 0.000000e+00, %L17.preheader ]
  %.not.not = icmp eq i64 %arraylen, 0
  br i1 %.not.not, label %L338, label %L31

L31:                                              ; preds = %L325, %L17
  %value_phi8 = phi float [ %287, %L325 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %288, %L325 ], [ 1, %L17 ]
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
  %29 = bitcast {}* %getfield12 to float**
  %arrayptr27145 = load float*, float** %29, align 8
  %30 = bitcast {}* %getfield14 to float**
  %arrayptr30146 = load float*, float** %30, align 8
  %min.iters.check293 = icmp ult i64 %arraylen115, 8
  br i1 %min.iters.check293, label %scalar.ph292, label %vector.ph294

vector.ph294:                                     ; preds = %L54.lr.ph
  %n.vec296 = and i64 %arraylen115, 9223372036854775800
  %31 = add nsw i64 %n.vec296, -8
  %32 = lshr exact i64 %31, 3
  %33 = add nuw nsw i64 %32, 1
  %xtraiter = and i64 %33, 3
  %34 = icmp ult i64 %31, 24
  br i1 %34, label %middle.block291.unr-lcssa, label %vector.ph294.new

vector.ph294.new:                                 ; preds = %vector.ph294
  %unroll_iter = and i64 %33, 4611686018427387900
  br label %vector.body299

vector.body299:                                   ; preds = %vector.body299, %vector.ph294.new
  %index300 = phi i64 [ 0, %vector.ph294.new ], [ %index.next306.3, %vector.body299 ]
  %vec.phi301 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294.new ], [ %74, %vector.body299 ]
  %vec.phi302 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294.new ], [ %76, %vector.body299 ]
  %vec.phi303 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294.new ], [ %78, %vector.body299 ]
  %niter = phi i64 [ 0, %vector.ph294.new ], [ %niter.next.3, %vector.body299 ]
  %35 = add i64 %28, %index300
  %36 = getelementptr inbounds float, float* %arrayptr27145, i64 %35
  %37 = bitcast float* %36 to <8 x float>*
  %wide.load304 = load <8 x float>, <8 x float>* %37, align 4
  %38 = getelementptr inbounds float, float* %arrayptr30146, i64 %index300
  %39 = bitcast float* %38 to <8 x float>*
  %wide.load305 = load <8 x float>, <8 x float>* %39, align 4
  %40 = fmul contract <8 x float> %wide.load304, %wide.load304
  %41 = fadd reassoc contract <8 x float> %vec.phi301, %40
  %42 = fmul contract <8 x float> %wide.load304, %wide.load305
  %43 = fadd reassoc contract <8 x float> %vec.phi302, %42
  %44 = fmul contract <8 x float> %wide.load305, %wide.load305
  %45 = fadd reassoc contract <8 x float> %vec.phi303, %44
  %index.next306 = or i64 %index300, 8
  %46 = add i64 %28, %index.next306
  %47 = getelementptr inbounds float, float* %arrayptr27145, i64 %46
  %48 = bitcast float* %47 to <8 x float>*
  %wide.load304.1 = load <8 x float>, <8 x float>* %48, align 4
  %49 = getelementptr inbounds float, float* %arrayptr30146, i64 %index.next306
  %50 = bitcast float* %49 to <8 x float>*
  %wide.load305.1 = load <8 x float>, <8 x float>* %50, align 4
  %51 = fmul contract <8 x float> %wide.load304.1, %wide.load304.1
  %52 = fadd reassoc contract <8 x float> %41, %51
  %53 = fmul contract <8 x float> %wide.load304.1, %wide.load305.1
  %54 = fadd reassoc contract <8 x float> %43, %53
  %55 = fmul contract <8 x float> %wide.load305.1, %wide.load305.1
  %56 = fadd reassoc contract <8 x float> %45, %55
  %index.next306.1 = or i64 %index300, 16
  %57 = add i64 %28, %index.next306.1
  %58 = getelementptr inbounds float, float* %arrayptr27145, i64 %57
  %59 = bitcast float* %58 to <8 x float>*
  %wide.load304.2 = load <8 x float>, <8 x float>* %59, align 4
  %60 = getelementptr inbounds float, float* %arrayptr30146, i64 %index.next306.1
  %61 = bitcast float* %60 to <8 x float>*
  %wide.load305.2 = load <8 x float>, <8 x float>* %61, align 4
  %62 = fmul contract <8 x float> %wide.load304.2, %wide.load304.2
  %63 = fadd reassoc contract <8 x float> %52, %62
  %64 = fmul contract <8 x float> %wide.load304.2, %wide.load305.2
  %65 = fadd reassoc contract <8 x float> %54, %64
  %66 = fmul contract <8 x float> %wide.load305.2, %wide.load305.2
  %67 = fadd reassoc contract <8 x float> %56, %66
  %index.next306.2 = or i64 %index300, 24
  %68 = add i64 %28, %index.next306.2
  %69 = getelementptr inbounds float, float* %arrayptr27145, i64 %68
  %70 = bitcast float* %69 to <8 x float>*
  %wide.load304.3 = load <8 x float>, <8 x float>* %70, align 4
  %71 = getelementptr inbounds float, float* %arrayptr30146, i64 %index.next306.2
  %72 = bitcast float* %71 to <8 x float>*
  %wide.load305.3 = load <8 x float>, <8 x float>* %72, align 4
  %73 = fmul contract <8 x float> %wide.load304.3, %wide.load304.3
  %74 = fadd reassoc contract <8 x float> %63, %73
  %75 = fmul contract <8 x float> %wide.load304.3, %wide.load305.3
  %76 = fadd reassoc contract <8 x float> %65, %75
  %77 = fmul contract <8 x float> %wide.load305.3, %wide.load305.3
  %78 = fadd reassoc contract <8 x float> %67, %77
  %index.next306.3 = add nuw i64 %index300, 32
  %niter.next.3 = add i64 %niter, 4
  %niter.ncmp.3 = icmp eq i64 %niter.next.3, %unroll_iter
  br i1 %niter.ncmp.3, label %middle.block291.unr-lcssa, label %vector.body299

middle.block291.unr-lcssa:                        ; preds = %vector.body299, %vector.ph294
  %.lcssa313.ph = phi <8 x float> [ undef, %vector.ph294 ], [ %74, %vector.body299 ]
  %.lcssa312.ph = phi <8 x float> [ undef, %vector.ph294 ], [ %76, %vector.body299 ]
  %.lcssa.ph = phi <8 x float> [ undef, %vector.ph294 ], [ %78, %vector.body299 ]
  %index300.unr = phi i64 [ 0, %vector.ph294 ], [ %index.next306.3, %vector.body299 ]
  %vec.phi301.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294 ], [ %74, %vector.body299 ]
  %vec.phi302.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294 ], [ %76, %vector.body299 ]
  %vec.phi303.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294 ], [ %78, %vector.body299 ]
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %middle.block291, label %vector.body299.epil

vector.body299.epil:                              ; preds = %vector.body299.epil, %middle.block291.unr-lcssa
  %index300.epil = phi i64 [ %index.next306.epil, %vector.body299.epil ], [ %index300.unr, %middle.block291.unr-lcssa ]
  %vec.phi301.epil = phi <8 x float> [ %85, %vector.body299.epil ], [ %vec.phi301.unr, %middle.block291.unr-lcssa ]
  %vec.phi302.epil = phi <8 x float> [ %87, %vector.body299.epil ], [ %vec.phi302.unr, %middle.block291.unr-lcssa ]
  %vec.phi303.epil = phi <8 x float> [ %89, %vector.body299.epil ], [ %vec.phi303.unr, %middle.block291.unr-lcssa ]
  %epil.iter = phi i64 [ %epil.iter.next, %vector.body299.epil ], [ 0, %middle.block291.unr-lcssa ]
  %79 = add i64 %28, %index300.epil
  %80 = getelementptr inbounds float, float* %arrayptr27145, i64 %79
  %81 = bitcast float* %80 to <8 x float>*
  %wide.load304.epil = load <8 x float>, <8 x float>* %81, align 4
  %82 = getelementptr inbounds float, float* %arrayptr30146, i64 %index300.epil
  %83 = bitcast float* %82 to <8 x float>*
  %wide.load305.epil = load <8 x float>, <8 x float>* %83, align 4
  %84 = fmul contract <8 x float> %wide.load304.epil, %wide.load304.epil
  %85 = fadd reassoc contract <8 x float> %vec.phi301.epil, %84
  %86 = fmul contract <8 x float> %wide.load304.epil, %wide.load305.epil
  %87 = fadd reassoc contract <8 x float> %vec.phi302.epil, %86
  %88 = fmul contract <8 x float> %wide.load305.epil, %wide.load305.epil
  %89 = fadd reassoc contract <8 x float> %vec.phi303.epil, %88
  %index.next306.epil = add nuw i64 %index300.epil, 8
  %epil.iter.next = add i64 %epil.iter, 1
  %epil.iter.cmp.not = icmp eq i64 %epil.iter.next, %xtraiter
  br i1 %epil.iter.cmp.not, label %middle.block291, label %vector.body299.epil

middle.block291:                                  ; preds = %vector.body299.epil, %middle.block291.unr-lcssa
  %.lcssa313 = phi <8 x float> [ %.lcssa313.ph, %middle.block291.unr-lcssa ], [ %85, %vector.body299.epil ]
  %.lcssa312 = phi <8 x float> [ %.lcssa312.ph, %middle.block291.unr-lcssa ], [ %87, %vector.body299.epil ]
  %.lcssa = phi <8 x float> [ %.lcssa.ph, %middle.block291.unr-lcssa ], [ %89, %vector.body299.epil ]
  %90 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa)
  %91 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa312)
  %92 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %.lcssa313)
  %cmp.n298 = icmp eq i64 %arraylen115, %n.vec296
  br i1 %cmp.n298, label %L124, label %scalar.ph292

scalar.ph292:                                     ; preds = %middle.block291, %L54.lr.ph
  %bc.resume.val297 = phi i64 [ %n.vec296, %middle.block291 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx307 = phi float [ %92, %middle.block291 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx308 = phi float [ %91, %middle.block291 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx309 = phi float [ %90, %middle.block291 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph292
  %value_phi25189 = phi float [ %bc.merge.rdx307, %scalar.ph292 ], [ %97, %L54 ]
  %value_phi24188 = phi i64 [ %bc.resume.val297, %scalar.ph292 ], [ %102, %L54 ]
  %value_phi23187 = phi float [ %bc.merge.rdx308, %scalar.ph292 ], [ %99, %L54 ]
  %value_phi22186 = phi float [ %bc.merge.rdx309, %scalar.ph292 ], [ %101, %L54 ]
  %93 = add i64 %28, %value_phi24188
  %94 = getelementptr inbounds float, float* %arrayptr27145, i64 %93
  %arrayref28 = load float, float* %94, align 4
  %95 = getelementptr inbounds float, float* %arrayptr30146, i64 %value_phi24188
  %arrayref31 = load float, float* %95, align 4
  %96 = fmul contract float %arrayref28, %arrayref28
  %97 = fadd reassoc contract float %value_phi25189, %96
  %98 = fmul contract float %arrayref28, %arrayref31
  %99 = fadd reassoc contract float %value_phi23187, %98
  %100 = fmul contract float %arrayref31, %arrayref31
  %101 = fadd reassoc contract float %value_phi22186, %100
  %102 = add nuw nsw i64 %value_phi24188, 1
  %exitcond.not = icmp eq i64 %102, %arraylen115
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not158, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %103 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr121 = getelementptr inbounds {}*, {}** %103, i64 3
  %104 = bitcast {}** %arraysize_ptr121 to i64*
  %arraysize122 = load i64, i64* %104, align 8
  %105 = mul i64 %arraysize122, %24
  %106 = bitcast {}* %getfield12 to float**
  %arrayptr125160 = load float*, float** %106, align 8
  %107 = bitcast {}* %getfield14 to float**
  %arrayptr128161 = load float*, float** %107, align 8
  %min.iters.check270 = icmp ult i64 %arraylen115, 16
  br i1 %min.iters.check270, label %scalar.ph269, label %vector.ph271

vector.ph271:                                     ; preds = %L96.lr.ph
  %n.vec273 = and i64 %arraylen115, 9223372036854775792
  %108 = add nsw i64 %n.vec273, -16
  %109 = lshr exact i64 %108, 4
  %110 = add nuw nsw i64 %109, 1
  %xtraiter352 = and i64 %110, 1
  %111 = icmp eq i64 %108, 0
  br i1 %111, label %middle.block268.unr-lcssa, label %vector.ph271.new

vector.ph271.new:                                 ; preds = %vector.ph271
  %unroll_iter359 = and i64 %110, 2305843009213693950
  br label %vector.body276

vector.body276:                                   ; preds = %vector.body276, %vector.ph271.new
  %index277 = phi i64 [ 0, %vector.ph271.new ], [ %index.next286.1, %vector.body276 ]
  %vec.phi278 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271.new ], [ %140, %vector.body276 ]
  %vec.phi279 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271.new ], [ %141, %vector.body276 ]
  %vec.phi280 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271.new ], [ %144, %vector.body276 ]
  %vec.phi281 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271.new ], [ %145, %vector.body276 ]
  %niter360 = phi i64 [ 0, %vector.ph271.new ], [ %niter360.next.1, %vector.body276 ]
  %112 = add i64 %105, %index277
  %113 = getelementptr inbounds float, float* %arrayptr125160, i64 %112
  %114 = bitcast float* %113 to <8 x float>*
  %wide.load282 = load <8 x float>, <8 x float>* %114, align 4
  %115 = getelementptr inbounds float, float* %113, i64 8
  %116 = bitcast float* %115 to <8 x float>*
  %wide.load283 = load <8 x float>, <8 x float>* %116, align 4
  %117 = getelementptr inbounds float, float* %arrayptr128161, i64 %index277
  %118 = bitcast float* %117 to <8 x float>*
  %wide.load284 = load <8 x float>, <8 x float>* %118, align 4
  %119 = getelementptr inbounds float, float* %117, i64 8
  %120 = bitcast float* %119 to <8 x float>*
  %wide.load285 = load <8 x float>, <8 x float>* %120, align 4
  %121 = fmul contract <8 x float> %wide.load282, %wide.load284
  %122 = fmul contract <8 x float> %wide.load283, %wide.load285
  %123 = fadd reassoc contract <8 x float> %vec.phi278, %121
  %124 = fadd reassoc contract <8 x float> %vec.phi279, %122
  %125 = fmul contract <8 x float> %wide.load284, %wide.load284
  %126 = fmul contract <8 x float> %wide.load285, %wide.load285
  %127 = fadd reassoc contract <8 x float> %vec.phi280, %125
  %128 = fadd reassoc contract <8 x float> %vec.phi281, %126
  %index.next286 = or i64 %index277, 16
  %129 = add i64 %105, %index.next286
  %130 = getelementptr inbounds float, float* %arrayptr125160, i64 %129
  %131 = bitcast float* %130 to <8 x float>*
  %wide.load282.1 = load <8 x float>, <8 x float>* %131, align 4
  %132 = getelementptr inbounds float, float* %130, i64 8
  %133 = bitcast float* %132 to <8 x float>*
  %wide.load283.1 = load <8 x float>, <8 x float>* %133, align 4
  %134 = getelementptr inbounds float, float* %arrayptr128161, i64 %index.next286
  %135 = bitcast float* %134 to <8 x float>*
  %wide.load284.1 = load <8 x float>, <8 x float>* %135, align 4
  %136 = getelementptr inbounds float, float* %134, i64 8
  %137 = bitcast float* %136 to <8 x float>*
  %wide.load285.1 = load <8 x float>, <8 x float>* %137, align 4
  %138 = fmul contract <8 x float> %wide.load282.1, %wide.load284.1
  %139 = fmul contract <8 x float> %wide.load283.1, %wide.load285.1
  %140 = fadd reassoc contract <8 x float> %123, %138
  %141 = fadd reassoc contract <8 x float> %124, %139
  %142 = fmul contract <8 x float> %wide.load284.1, %wide.load284.1
  %143 = fmul contract <8 x float> %wide.load285.1, %wide.load285.1
  %144 = fadd reassoc contract <8 x float> %127, %142
  %145 = fadd reassoc contract <8 x float> %128, %143
  %index.next286.1 = add nuw i64 %index277, 32
  %niter360.next.1 = add i64 %niter360, 2
  %niter360.ncmp.1 = icmp eq i64 %niter360.next.1, %unroll_iter359
  br i1 %niter360.ncmp.1, label %middle.block268.unr-lcssa, label %vector.body276

middle.block268.unr-lcssa:                        ; preds = %vector.body276, %vector.ph271
  %.lcssa320.ph = phi <8 x float> [ undef, %vector.ph271 ], [ %140, %vector.body276 ]
  %.lcssa319.ph = phi <8 x float> [ undef, %vector.ph271 ], [ %141, %vector.body276 ]
  %.lcssa318.ph = phi <8 x float> [ undef, %vector.ph271 ], [ %144, %vector.body276 ]
  %.lcssa317.ph = phi <8 x float> [ undef, %vector.ph271 ], [ %145, %vector.body276 ]
  %index277.unr = phi i64 [ 0, %vector.ph271 ], [ %index.next286.1, %vector.body276 ]
  %vec.phi278.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %140, %vector.body276 ]
  %vec.phi279.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %141, %vector.body276 ]
  %vec.phi280.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %144, %vector.body276 ]
  %vec.phi281.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %145, %vector.body276 ]
  %lcmp.mod354.not = icmp eq i64 %xtraiter352, 0
  br i1 %lcmp.mod354.not, label %middle.block268, label %vector.body276.epil.preheader

vector.body276.epil.preheader:                    ; preds = %middle.block268.unr-lcssa
  %146 = add i64 %105, %index277.unr
  %147 = getelementptr inbounds float, float* %arrayptr125160, i64 %146
  %148 = bitcast float* %147 to <8 x float>*
  %wide.load282.epil = load <8 x float>, <8 x float>* %148, align 4
  %149 = getelementptr inbounds float, float* %147, i64 8
  %150 = bitcast float* %149 to <8 x float>*
  %wide.load283.epil = load <8 x float>, <8 x float>* %150, align 4
  %151 = getelementptr inbounds float, float* %arrayptr128161, i64 %index277.unr
  %152 = bitcast float* %151 to <8 x float>*
  %wide.load284.epil = load <8 x float>, <8 x float>* %152, align 4
  %153 = getelementptr inbounds float, float* %151, i64 8
  %154 = bitcast float* %153 to <8 x float>*
  %wide.load285.epil = load <8 x float>, <8 x float>* %154, align 4
  %155 = fmul contract <8 x float> %wide.load282.epil, %wide.load284.epil
  %156 = fmul contract <8 x float> %wide.load283.epil, %wide.load285.epil
  %157 = fadd reassoc contract <8 x float> %vec.phi278.unr, %155
  %158 = fadd reassoc contract <8 x float> %vec.phi279.unr, %156
  %159 = fmul contract <8 x float> %wide.load284.epil, %wide.load284.epil
  %160 = fmul contract <8 x float> %wide.load285.epil, %wide.load285.epil
  %161 = fadd reassoc contract <8 x float> %vec.phi280.unr, %159
  %162 = fadd reassoc contract <8 x float> %vec.phi281.unr, %160
  br label %middle.block268

middle.block268:                                  ; preds = %vector.body276.epil.preheader, %middle.block268.unr-lcssa
  %.lcssa320 = phi <8 x float> [ %.lcssa320.ph, %middle.block268.unr-lcssa ], [ %157, %vector.body276.epil.preheader ]
  %.lcssa319 = phi <8 x float> [ %.lcssa319.ph, %middle.block268.unr-lcssa ], [ %158, %vector.body276.epil.preheader ]
  %.lcssa318 = phi <8 x float> [ %.lcssa318.ph, %middle.block268.unr-lcssa ], [ %161, %vector.body276.epil.preheader ]
  %.lcssa317 = phi <8 x float> [ %.lcssa317.ph, %middle.block268.unr-lcssa ], [ %162, %vector.body276.epil.preheader ]
  %bin.rdx289 = fadd reassoc contract <8 x float> %.lcssa317, %.lcssa318
  %163 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx289)
  %bin.rdx287 = fadd reassoc contract <8 x float> %.lcssa319, %.lcssa320
  %164 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx287)
  %cmp.n275 = icmp eq i64 %arraylen115, %n.vec273
  br i1 %cmp.n275, label %L124, label %scalar.ph269

scalar.ph269:                                     ; preds = %middle.block268, %L96.lr.ph
  %bc.resume.val274 = phi i64 [ %n.vec273, %middle.block268 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx288 = phi float [ %164, %middle.block268 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx290 = phi float [ %163, %middle.block268 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph269
  %value_phi120195 = phi i64 [ %bc.resume.val274, %scalar.ph269 ], [ %172, %L96 ]
  %value_phi119194 = phi float [ %bc.merge.rdx288, %scalar.ph269 ], [ %169, %L96 ]
  %value_phi118193 = phi float [ %bc.merge.rdx290, %scalar.ph269 ], [ %171, %L96 ]
  %165 = add i64 %105, %value_phi120195
  %166 = getelementptr inbounds float, float* %arrayptr125160, i64 %165
  %arrayref126 = load float, float* %166, align 4
  %167 = getelementptr inbounds float, float* %arrayptr128161, i64 %value_phi120195
  %arrayref129 = load float, float* %167, align 4
  %168 = fmul contract float %arrayref126, %arrayref129
  %169 = fadd reassoc contract float %value_phi119194, %168
  %170 = fmul contract float %arrayref129, %arrayref129
  %171 = fadd reassoc contract float %value_phi118193, %170
  %172 = add nuw nsw i64 %value_phi120195, 1
  %exitcond202.not = icmp eq i64 %172, %arraylen115
  br i1 %exitcond202.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block268, %L83, %L54, %middle.block291, %L40
  %value_phi38 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %163, %middle.block268 ], [ %90, %middle.block291 ], [ %171, %L96 ], [ %101, %L54 ]
  %value_phi39 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %164, %middle.block268 ], [ %91, %middle.block291 ], [ %169, %L96 ], [ %99, %L54 ]
  %value_phi40 = phi float [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block268 ], [ %92, %middle.block291 ], [ %arrayref, %L96 ], [ %97, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %24, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L144:                                             ; preds = %idxend46
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %173 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %173, label %L150, label %L148

L148:                                             ; preds = %L144
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 140312453360144 to {}*), float %value_phi40) #2
  unreachable

L150:                                             ; preds = %L144
  %174 = call float @llvm.sqrt.f32(float %value_phi40)
  %175 = fcmp ugt float %174, %aggregate_load_box.sroa.0.0.copyload
  br i1 %175, label %L155, label %L325

L155:                                             ; preds = %L150
  %176 = fdiv float %value_phi39, %value_phi40
  %177 = fadd float %176, %arrayref49
  %178 = fmul float %value_phi39, %176
  %179 = fsub float %value_phi38, %178
  %180 = fmul float %value_phi38, 6.250000e-02
  %181 = fcmp uge float %179, %180
  br i1 %181, label %L210, label %L162

L162:                                             ; preds = %L155
  %.not150 = icmp eq i64 %arraylen55, 0
  br i1 %.not150, label %L199, label %L176.lr.ph

L176.lr.ph:                                       ; preds = %L162
  %182 = bitcast {}* %getfield51 to {}**
  %getfield66 = load atomic {}*, {}** %182 unordered, align 8
  %183 = bitcast {}* %getfield53 to float**
  %arrayptr76152 = load float*, float** %183, align 8
  %184 = bitcast {}* %getfield66 to {}**
  %arraysize_ptr78 = getelementptr inbounds {}*, {}** %184, i64 3
  %185 = bitcast {}** %arraysize_ptr78 to i64*
  %arraysize79 = load i64, i64* %185, align 8
  %186 = mul i64 %arraysize79, %24
  %187 = bitcast {}* %getfield66 to float**
  %arrayptr82153 = load float*, float** %187, align 8
  %min.iters.check = icmp ult i64 %arraylen55, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L176.lr.ph
  %n.vec = and i64 %arraylen55, 9223372036854775792
  %broadcast.splatinsert = insertelement <8 x float> poison, float %176, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  %188 = add nsw i64 %n.vec, -16
  %189 = lshr exact i64 %188, 4
  %190 = add nuw nsw i64 %189, 1
  %xtraiter361 = and i64 %190, 1
  %191 = icmp eq i64 %188, 0
  br i1 %191, label %middle.block.unr-lcssa, label %vector.ph.new

vector.ph.new:                                    ; preds = %vector.ph
  %unroll_iter366 = and i64 %190, 2305843009213693950
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph.new
  %index = phi i64 [ 0, %vector.ph.new ], [ %index.next.1, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph.new ], [ %224, %vector.body ]
  %vec.phi262 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph.new ], [ %225, %vector.body ]
  %niter367 = phi i64 [ 0, %vector.ph.new ], [ %niter367.next.1, %vector.body ]
  %192 = getelementptr inbounds float, float* %arrayptr76152, i64 %index
  %193 = bitcast float* %192 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %193, align 4
  %194 = getelementptr inbounds float, float* %192, i64 8
  %195 = bitcast float* %194 to <8 x float>*
  %wide.load263 = load <8 x float>, <8 x float>* %195, align 4
  %196 = add i64 %186, %index
  %197 = getelementptr inbounds float, float* %arrayptr82153, i64 %196
  %198 = bitcast float* %197 to <8 x float>*
  %wide.load264 = load <8 x float>, <8 x float>* %198, align 4
  %199 = getelementptr inbounds float, float* %197, i64 8
  %200 = bitcast float* %199 to <8 x float>*
  %wide.load265 = load <8 x float>, <8 x float>* %200, align 4
  %201 = fmul <8 x float> %broadcast.splat, %wide.load264
  %202 = fmul <8 x float> %broadcast.splat, %wide.load265
  %203 = fsub <8 x float> %wide.load, %201
  %204 = fsub <8 x float> %wide.load263, %202
  %205 = fmul contract <8 x float> %203, %203
  %206 = fmul contract <8 x float> %204, %204
  %207 = fadd reassoc contract <8 x float> %vec.phi, %205
  %208 = fadd reassoc contract <8 x float> %vec.phi262, %206
  %index.next = or i64 %index, 16
  %209 = getelementptr inbounds float, float* %arrayptr76152, i64 %index.next
  %210 = bitcast float* %209 to <8 x float>*
  %wide.load.1 = load <8 x float>, <8 x float>* %210, align 4
  %211 = getelementptr inbounds float, float* %209, i64 8
  %212 = bitcast float* %211 to <8 x float>*
  %wide.load263.1 = load <8 x float>, <8 x float>* %212, align 4
  %213 = add i64 %186, %index.next
  %214 = getelementptr inbounds float, float* %arrayptr82153, i64 %213
  %215 = bitcast float* %214 to <8 x float>*
  %wide.load264.1 = load <8 x float>, <8 x float>* %215, align 4
  %216 = getelementptr inbounds float, float* %214, i64 8
  %217 = bitcast float* %216 to <8 x float>*
  %wide.load265.1 = load <8 x float>, <8 x float>* %217, align 4
  %218 = fmul <8 x float> %broadcast.splat, %wide.load264.1
  %219 = fmul <8 x float> %broadcast.splat, %wide.load265.1
  %220 = fsub <8 x float> %wide.load.1, %218
  %221 = fsub <8 x float> %wide.load263.1, %219
  %222 = fmul contract <8 x float> %220, %220
  %223 = fmul contract <8 x float> %221, %221
  %224 = fadd reassoc contract <8 x float> %207, %222
  %225 = fadd reassoc contract <8 x float> %208, %223
  %index.next.1 = add nuw i64 %index, 32
  %niter367.next.1 = add i64 %niter367, 2
  %niter367.ncmp.1 = icmp eq i64 %niter367.next.1, %unroll_iter366
  br i1 %niter367.ncmp.1, label %middle.block.unr-lcssa, label %vector.body

middle.block.unr-lcssa:                           ; preds = %vector.body, %vector.ph
  %.lcssa324.ph = phi <8 x float> [ undef, %vector.ph ], [ %224, %vector.body ]
  %.lcssa323.ph = phi <8 x float> [ undef, %vector.ph ], [ %225, %vector.body ]
  %index.unr = phi i64 [ 0, %vector.ph ], [ %index.next.1, %vector.body ]
  %vec.phi.unr = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %224, %vector.body ]
  %vec.phi262.unr = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %225, %vector.body ]
  %lcmp.mod363.not = icmp eq i64 %xtraiter361, 0
  br i1 %lcmp.mod363.not, label %middle.block, label %vector.body.epil.preheader

vector.body.epil.preheader:                       ; preds = %middle.block.unr-lcssa
  %226 = getelementptr inbounds float, float* %arrayptr76152, i64 %index.unr
  %227 = bitcast float* %226 to <8 x float>*
  %wide.load.epil = load <8 x float>, <8 x float>* %227, align 4
  %228 = getelementptr inbounds float, float* %226, i64 8
  %229 = bitcast float* %228 to <8 x float>*
  %wide.load263.epil = load <8 x float>, <8 x float>* %229, align 4
  %230 = add i64 %186, %index.unr
  %231 = getelementptr inbounds float, float* %arrayptr82153, i64 %230
  %232 = bitcast float* %231 to <8 x float>*
  %wide.load264.epil = load <8 x float>, <8 x float>* %232, align 4
  %233 = getelementptr inbounds float, float* %231, i64 8
  %234 = bitcast float* %233 to <8 x float>*
  %wide.load265.epil = load <8 x float>, <8 x float>* %234, align 4
  %235 = fmul <8 x float> %broadcast.splat, %wide.load264.epil
  %236 = fmul <8 x float> %broadcast.splat, %wide.load265.epil
  %237 = fsub <8 x float> %wide.load.epil, %235
  %238 = fsub <8 x float> %wide.load263.epil, %236
  %239 = fmul contract <8 x float> %237, %237
  %240 = fmul contract <8 x float> %238, %238
  %241 = fadd reassoc contract <8 x float> %vec.phi.unr, %239
  %242 = fadd reassoc contract <8 x float> %vec.phi262.unr, %240
  br label %middle.block

middle.block:                                     ; preds = %vector.body.epil.preheader, %middle.block.unr-lcssa
  %.lcssa324 = phi <8 x float> [ %.lcssa324.ph, %middle.block.unr-lcssa ], [ %241, %vector.body.epil.preheader ]
  %.lcssa323 = phi <8 x float> [ %.lcssa323.ph, %middle.block.unr-lcssa ], [ %242, %vector.body.epil.preheader ]
  %bin.rdx = fadd reassoc contract <8 x float> %.lcssa323, %.lcssa324
  %243 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n = icmp eq i64 %arraylen55, %n.vec
  br i1 %cmp.n, label %L199, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L176.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L176.lr.ph ]
  %bc.merge.rdx = phi float [ %243, %middle.block ], [ 0.000000e+00, %L176.lr.ph ]
  br label %L176

L176:                                             ; preds = %L176, %scalar.ph
  %value_phi74200 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %251, %L176 ]
  %value_phi73199 = phi float [ %bc.merge.rdx, %scalar.ph ], [ %250, %L176 ]
  %244 = getelementptr inbounds float, float* %arrayptr76152, i64 %value_phi74200
  %arrayref77 = load float, float* %244, align 4
  %245 = add i64 %186, %value_phi74200
  %246 = getelementptr inbounds float, float* %arrayptr82153, i64 %245
  %arrayref83 = load float, float* %246, align 4
  %247 = fmul float %176, %arrayref83
  %248 = fsub float %arrayref77, %247
  %249 = fmul contract float %248, %248
  %250 = fadd reassoc contract float %value_phi73199, %249
  %251 = add nuw nsw i64 %value_phi74200, 1
  %exitcond203.not = icmp eq i64 %251, %arraylen55
  br i1 %exitcond203.not, label %L199, label %L176

L199:                                             ; preds = %L176, %middle.block, %L162
  %value_phi85 = phi float [ 0.000000e+00, %L162 ], [ %243, %middle.block ], [ %250, %L176 ]
  %252 = fsub float %value_phi85, %value_phi85
  %253 = fcmp uno float %252, 0.000000e+00
  %254 = fcmp ugt float %302, %value_phi85
  %255 = or i1 %254, %253
  br i1 %255, label %L208, label %L210

L208:                                             ; preds = %L199
  %256 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe369, i64 0, i64 2
  store {}* %getfield, {}** %256, align 16
  %257 = call float @j__sqrt_offrange_step_1657({}* nonnull %0, float %arrayref49, i64 signext %value_phi9)
  br label %L325

L210:                                             ; preds = %L199, %L155
  %value_phi87 = phi float [ %179, %L155 ], [ %value_phi85, %L199 ]
  %258 = fcmp uge float %value_phi87, 0.000000e+00
  br i1 %258, label %L215, label %L213

L213:                                             ; preds = %L210
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 140312453360144 to {}*), float %value_phi87) #2
  unreachable

L215:                                             ; preds = %L210
  %259 = call float @llvm.sqrt.f32(float %value_phi87)
  %260 = fsub float %174, %aggregate_load_box.sroa.0.0.copyload
  %261 = fcmp uge float %260, 0.000000e+00
  br i1 %261, label %L222, label %L220

L220:                                             ; preds = %L215
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 140312453360144 to {}*), float %260) #2
  unreachable

L222:                                             ; preds = %L215
  %262 = fadd float %174, %aggregate_load_box.sroa.0.0.copyload
  %263 = fcmp uge float %262, 0.000000e+00
  br i1 %263, label %L229, label %L227

L227:                                             ; preds = %L222
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 140312453360144 to {}*), float %262) #2
  unreachable

L229:                                             ; preds = %L222
  %264 = call float @llvm.sqrt.f32(float %260)
  %265 = call float @llvm.sqrt.f32(float %262)
  %266 = fmul float %264, %265
  %267 = fmul float %174, %266
  %268 = fdiv float %259, %267
  %269 = fmul float %aggregate_load_box.sroa.0.0.copyload, %268
  %270 = fcmp oge float %267, 0x3810000000000000
  %271 = fcmp oge float %268, 0x3810000000000000
  %272 = fcmp ole float %268, 0x47EFFFFFE0000000
  %narrow = and i1 %271, %272
  %273 = and i1 %270, %narrow
  %274 = fcmp oge float %269, 0x3810000000000000
  %275 = fcmp ole float %269, 0x47EFFFFFE0000000
  %narrow154 = and i1 %274, %275
  %276 = and i1 %273, %narrow154
  br i1 %276, label %L263, label %L320

L263:                                             ; preds = %L229
  %277 = fneg float %269
  %.inv = fcmp ogt float %177, %277
  %278 = select i1 %.inv, float %177, float %277
  %.inv156 = fcmp olt float %278, %269
  %279 = select i1 %.inv156, float %278, float %269
  %280 = fsub float %177, %279
  %281 = fadd float %280, 0.000000e+00
  br label %L325

L320:                                             ; preds = %L229
  %282 = fpext float %259 to double
  %283 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe369, i64 0, i64 2
  store {}* %getfield, {}** %283, align 16
  %284 = call float @j__sqrt_band_step_1656(float %177, float %174, float %aggregate_load_box.sroa.0.0.copyload, double %282, i64 signext 0)
  br label %L325

L323:                                             ; preds = %idxend46
  %285 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe369, i64 0, i64 2
  store {}* %getfield, {}** %285, align 16
  %286 = call float @j__sqrt_offrange_step_1657({}* nonnull %0, float %arrayref49, i64 signext %value_phi9)
  br label %L325

L325:                                             ; preds = %L323, %L320, %L263, %L208, %L150
  %value_phi57 = phi float [ %257, %L208 ], [ %284, %L320 ], [ %286, %L323 ], [ 0.000000e+00, %L150 ], [ %281, %L263 ]
  %287 = fadd float %value_phi8, %value_phi57
  %.not148.not = icmp eq i64 %value_phi9, %arraylen
  %288 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not148.not, label %L338, label %L31

L338:                                             ; preds = %L325, %L17
  %value_phi61 = phi float [ %value_phi4, %L17 ], [ %287, %L325 ]
  %.not149 = icmp eq i64 %value_phi3, %11
  br i1 %.not149, label %L349, label %L17thread-pre-split

L349:                                             ; preds = %L338, %L17.preheader, %top
  %value_phi64 = phi float [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi61, %L338 ]
  %289 = load {}*, {}** %6, align 8
  %290 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %289, {}** %290, align 8
  ret float %value_phi64

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %291 = bitcast {}* %getfield16 to float**
  %arrayptr143 = load float*, float** %291, align 8
  %292 = getelementptr inbounds float, float* %arrayptr143, i64 %24
  %arrayref = load float, float* %292, align 4
  %293 = fcmp ord float %arrayref, 0.000000e+00
  %294 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr114 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %294, i64 0, i32 1
  %arraylen115 = load i64, i64* %arraylen_ptr114, align 8
  %.not158 = icmp eq i64 %arraylen115, 0
  br i1 %293, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48147 = load float*, float** %18, align 8
  %295 = getelementptr inbounds float, float* %arrayptr48147, i64 %24
  %arrayref49 = load float, float* %295, align 4
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %296 = bitcast {}* %getfield51 to i8*
  %getfield_addr52 = getelementptr inbounds i8, i8* %296, i64 24
  %297 = bitcast i8* %getfield_addr52 to {}**
  %getfield53 = load atomic {}*, {}** %297 unordered, align 8
  %298 = bitcast {}* %getfield53 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr54 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %298, i64 0, i32 1
  %arraylen55 = load i64, i64* %arraylen_ptr54, align 8
  %299 = fsub float %value_phi40, %value_phi40
  %300 = fcmp ord float %299, 0.000000e+00
  %301 = sitofp i64 %arraylen55 to float
  %302 = fmul float %301, 0x3980000000000000
  %303 = fcmp ole float %302, %value_phi40
  %304 = and i1 %300, %303
  %305 = fsub float %value_phi38, %value_phi38
  %306 = fcmp ord float %305, 0.000000e+00
  %307 = fcmp ole float %302, %value_phi38
  %308 = and i1 %306, %307
  %309 = and i1 %304, %308
  br i1 %309, label %L144, label %L323
}
