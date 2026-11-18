; Function Attrs: noinline
define float @julia_pass_1651({}* noundef nonnull align 8 dereferenceable(72) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe350 = alloca [3 x {}*], align 16
  %gcframe350.sub = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe350, i64 0, i64 0
  %3 = bitcast [3 x {}*]* %gcframe350 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 24, i1 true)
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %4 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %4, align 8
  %5 = bitcast [3 x {}*]* %gcframe350 to i64*
  store i64 4, i64* %5, align 16
  %6 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe350, i64 0, i64 1
  %7 = bitcast {}** %6 to {}***
  %8 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %8, {}*** %7, align 8
  %9 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe350.sub, {}*** %9, align 8
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
  %value_phi8 = phi float [ %166, %L325 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %167, %L325 ], [ 1, %L17 ]
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
  br label %vector.body299

vector.body299:                                   ; preds = %vector.body299, %vector.ph294
  %index300 = phi i64 [ 0, %vector.ph294 ], [ %index.next306, %vector.body299 ]
  %vec.phi301 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294 ], [ %37, %vector.body299 ]
  %vec.phi302 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294 ], [ %39, %vector.body299 ]
  %vec.phi303 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph294 ], [ %41, %vector.body299 ]
  %31 = add i64 %28, %index300
  %32 = getelementptr inbounds float, float* %arrayptr27145, i64 %31
  %33 = bitcast float* %32 to <8 x float>*
  %wide.load304 = load <8 x float>, <8 x float>* %33, align 4
  %34 = getelementptr inbounds float, float* %arrayptr30146, i64 %index300
  %35 = bitcast float* %34 to <8 x float>*
  %wide.load305 = load <8 x float>, <8 x float>* %35, align 4
  %36 = fmul contract <8 x float> %wide.load304, %wide.load304
  %37 = fadd reassoc contract <8 x float> %vec.phi301, %36
  %38 = fmul contract <8 x float> %wide.load304, %wide.load305
  %39 = fadd reassoc contract <8 x float> %vec.phi302, %38
  %40 = fmul contract <8 x float> %wide.load305, %wide.load305
  %41 = fadd reassoc contract <8 x float> %vec.phi303, %40
  %index.next306 = add nuw i64 %index300, 8
  %42 = icmp eq i64 %index.next306, %n.vec296
  br i1 %42, label %middle.block291, label %vector.body299

middle.block291:                                  ; preds = %vector.body299
  %43 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %41)
  %44 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %39)
  %45 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %37)
  %cmp.n298 = icmp eq i64 %arraylen115, %n.vec296
  br i1 %cmp.n298, label %L124, label %scalar.ph292

scalar.ph292:                                     ; preds = %middle.block291, %L54.lr.ph
  %bc.resume.val297 = phi i64 [ %n.vec296, %middle.block291 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx307 = phi float [ %45, %middle.block291 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx308 = phi float [ %44, %middle.block291 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx309 = phi float [ %43, %middle.block291 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph292
  %value_phi25189 = phi float [ %bc.merge.rdx307, %scalar.ph292 ], [ %50, %L54 ]
  %value_phi24188 = phi i64 [ %bc.resume.val297, %scalar.ph292 ], [ %55, %L54 ]
  %value_phi23187 = phi float [ %bc.merge.rdx308, %scalar.ph292 ], [ %52, %L54 ]
  %value_phi22186 = phi float [ %bc.merge.rdx309, %scalar.ph292 ], [ %54, %L54 ]
  %46 = add i64 %28, %value_phi24188
  %47 = getelementptr inbounds float, float* %arrayptr27145, i64 %46
  %arrayref28 = load float, float* %47, align 4
  %48 = getelementptr inbounds float, float* %arrayptr30146, i64 %value_phi24188
  %arrayref31 = load float, float* %48, align 4
  %49 = fmul contract float %arrayref28, %arrayref28
  %50 = fadd reassoc contract float %value_phi25189, %49
  %51 = fmul contract float %arrayref28, %arrayref31
  %52 = fadd reassoc contract float %value_phi23187, %51
  %53 = fmul contract float %arrayref31, %arrayref31
  %54 = fadd reassoc contract float %value_phi22186, %53
  %55 = add nuw nsw i64 %value_phi24188, 1
  %exitcond.not = icmp eq i64 %55, %arraylen115
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not158, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %56 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr121 = getelementptr inbounds {}*, {}** %56, i64 3
  %57 = bitcast {}** %arraysize_ptr121 to i64*
  %arraysize122 = load i64, i64* %57, align 8
  %58 = mul i64 %arraysize122, %24
  %59 = bitcast {}* %getfield12 to float**
  %arrayptr125160 = load float*, float** %59, align 8
  %60 = bitcast {}* %getfield14 to float**
  %arrayptr128161 = load float*, float** %60, align 8
  %min.iters.check270 = icmp ult i64 %arraylen115, 16
  br i1 %min.iters.check270, label %scalar.ph269, label %vector.ph271

vector.ph271:                                     ; preds = %L96.lr.ph
  %n.vec273 = and i64 %arraylen115, 9223372036854775792
  br label %vector.body276

vector.body276:                                   ; preds = %vector.body276, %vector.ph271
  %index277 = phi i64 [ 0, %vector.ph271 ], [ %index.next286, %vector.body276 ]
  %vec.phi278 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %72, %vector.body276 ]
  %vec.phi279 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %73, %vector.body276 ]
  %vec.phi280 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %76, %vector.body276 ]
  %vec.phi281 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph271 ], [ %77, %vector.body276 ]
  %61 = add i64 %58, %index277
  %62 = getelementptr inbounds float, float* %arrayptr125160, i64 %61
  %63 = bitcast float* %62 to <8 x float>*
  %wide.load282 = load <8 x float>, <8 x float>* %63, align 4
  %64 = getelementptr inbounds float, float* %62, i64 8
  %65 = bitcast float* %64 to <8 x float>*
  %wide.load283 = load <8 x float>, <8 x float>* %65, align 4
  %66 = getelementptr inbounds float, float* %arrayptr128161, i64 %index277
  %67 = bitcast float* %66 to <8 x float>*
  %wide.load284 = load <8 x float>, <8 x float>* %67, align 4
  %68 = getelementptr inbounds float, float* %66, i64 8
  %69 = bitcast float* %68 to <8 x float>*
  %wide.load285 = load <8 x float>, <8 x float>* %69, align 4
  %70 = fmul contract <8 x float> %wide.load282, %wide.load284
  %71 = fmul contract <8 x float> %wide.load283, %wide.load285
  %72 = fadd reassoc contract <8 x float> %vec.phi278, %70
  %73 = fadd reassoc contract <8 x float> %vec.phi279, %71
  %74 = fmul contract <8 x float> %wide.load284, %wide.load284
  %75 = fmul contract <8 x float> %wide.load285, %wide.load285
  %76 = fadd reassoc contract <8 x float> %vec.phi280, %74
  %77 = fadd reassoc contract <8 x float> %vec.phi281, %75
  %index.next286 = add nuw i64 %index277, 16
  %78 = icmp eq i64 %index.next286, %n.vec273
  br i1 %78, label %middle.block268, label %vector.body276

middle.block268:                                  ; preds = %vector.body276
  %bin.rdx289 = fadd reassoc contract <8 x float> %77, %76
  %79 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx289)
  %bin.rdx287 = fadd reassoc contract <8 x float> %73, %72
  %80 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx287)
  %cmp.n275 = icmp eq i64 %arraylen115, %n.vec273
  br i1 %cmp.n275, label %L124, label %scalar.ph269

scalar.ph269:                                     ; preds = %middle.block268, %L96.lr.ph
  %bc.resume.val274 = phi i64 [ %n.vec273, %middle.block268 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx288 = phi float [ %80, %middle.block268 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx290 = phi float [ %79, %middle.block268 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph269
  %value_phi120195 = phi i64 [ %bc.resume.val274, %scalar.ph269 ], [ %88, %L96 ]
  %value_phi119194 = phi float [ %bc.merge.rdx288, %scalar.ph269 ], [ %85, %L96 ]
  %value_phi118193 = phi float [ %bc.merge.rdx290, %scalar.ph269 ], [ %87, %L96 ]
  %81 = add i64 %58, %value_phi120195
  %82 = getelementptr inbounds float, float* %arrayptr125160, i64 %81
  %arrayref126 = load float, float* %82, align 4
  %83 = getelementptr inbounds float, float* %arrayptr128161, i64 %value_phi120195
  %arrayref129 = load float, float* %83, align 4
  %84 = fmul contract float %arrayref126, %arrayref129
  %85 = fadd reassoc contract float %value_phi119194, %84
  %86 = fmul contract float %arrayref129, %arrayref129
  %87 = fadd reassoc contract float %value_phi118193, %86
  %88 = add nuw nsw i64 %value_phi120195, 1
  %exitcond202.not = icmp eq i64 %88, %arraylen115
  br i1 %exitcond202.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block268, %L83, %L54, %middle.block291, %L40
  %value_phi38 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %79, %middle.block268 ], [ %43, %middle.block291 ], [ %87, %L96 ], [ %54, %L54 ]
  %value_phi39 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %80, %middle.block268 ], [ %44, %middle.block291 ], [ %85, %L96 ], [ %52, %L54 ]
  %value_phi40 = phi float [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block268 ], [ %45, %middle.block291 ], [ %arrayref, %L96 ], [ %50, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %24, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L144:                                             ; preds = %idxend46
  %aggregate_load_box.sroa.0.0.copyload = load float, float* %aggregate_load_box.sroa.0.0..sroa_idx, align 1
  %89 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %89, label %L150, label %L148

L148:                                             ; preds = %L144
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 136709640595984 to {}*), float %value_phi40) #2
  unreachable

L150:                                             ; preds = %L144
  %90 = call float @llvm.sqrt.f32(float %value_phi40)
  %91 = fcmp ugt float %90, %aggregate_load_box.sroa.0.0.copyload
  br i1 %91, label %L155, label %L325

L155:                                             ; preds = %L150
  %92 = fdiv float %value_phi39, %value_phi40
  %93 = fadd float %92, %arrayref49
  %94 = fmul float %value_phi39, %92
  %95 = fsub float %value_phi38, %94
  %96 = fmul float %value_phi38, 6.250000e-02
  %97 = fcmp uge float %95, %96
  br i1 %97, label %L210, label %L162

L162:                                             ; preds = %L155
  %.not150 = icmp eq i64 %arraylen55, 0
  br i1 %.not150, label %L199, label %L176.lr.ph

L176.lr.ph:                                       ; preds = %L162
  %98 = bitcast {}* %getfield51 to {}**
  %getfield66 = load atomic {}*, {}** %98 unordered, align 8
  %99 = bitcast {}* %getfield53 to float**
  %arrayptr76152 = load float*, float** %99, align 8
  %100 = bitcast {}* %getfield66 to {}**
  %arraysize_ptr78 = getelementptr inbounds {}*, {}** %100, i64 3
  %101 = bitcast {}** %arraysize_ptr78 to i64*
  %arraysize79 = load i64, i64* %101, align 8
  %102 = mul i64 %arraysize79, %24
  %103 = bitcast {}* %getfield66 to float**
  %arrayptr82153 = load float*, float** %103, align 8
  %min.iters.check = icmp ult i64 %arraylen55, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L176.lr.ph
  %n.vec = and i64 %arraylen55, 9223372036854775792
  %broadcast.splatinsert = insertelement <8 x float> poison, float %92, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %119, %vector.body ]
  %vec.phi262 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %120, %vector.body ]
  %104 = getelementptr inbounds float, float* %arrayptr76152, i64 %index
  %105 = bitcast float* %104 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %105, align 4
  %106 = getelementptr inbounds float, float* %104, i64 8
  %107 = bitcast float* %106 to <8 x float>*
  %wide.load263 = load <8 x float>, <8 x float>* %107, align 4
  %108 = add i64 %102, %index
  %109 = getelementptr inbounds float, float* %arrayptr82153, i64 %108
  %110 = bitcast float* %109 to <8 x float>*
  %wide.load264 = load <8 x float>, <8 x float>* %110, align 4
  %111 = getelementptr inbounds float, float* %109, i64 8
  %112 = bitcast float* %111 to <8 x float>*
  %wide.load265 = load <8 x float>, <8 x float>* %112, align 4
  %113 = fmul <8 x float> %broadcast.splat, %wide.load264
  %114 = fmul <8 x float> %broadcast.splat, %wide.load265
  %115 = fsub <8 x float> %wide.load, %113
  %116 = fsub <8 x float> %wide.load263, %114
  %117 = fmul contract <8 x float> %115, %115
  %118 = fmul contract <8 x float> %116, %116
  %119 = fadd reassoc contract <8 x float> %vec.phi, %117
  %120 = fadd reassoc contract <8 x float> %vec.phi262, %118
  %index.next = add nuw i64 %index, 16
  %121 = icmp eq i64 %index.next, %n.vec
  br i1 %121, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <8 x float> %120, %119
  %122 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n = icmp eq i64 %arraylen55, %n.vec
  br i1 %cmp.n, label %L199, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L176.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L176.lr.ph ]
  %bc.merge.rdx = phi float [ %122, %middle.block ], [ 0.000000e+00, %L176.lr.ph ]
  br label %L176

L176:                                             ; preds = %L176, %scalar.ph
  %value_phi74200 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %130, %L176 ]
  %value_phi73199 = phi float [ %bc.merge.rdx, %scalar.ph ], [ %129, %L176 ]
  %123 = getelementptr inbounds float, float* %arrayptr76152, i64 %value_phi74200
  %arrayref77 = load float, float* %123, align 4
  %124 = add i64 %102, %value_phi74200
  %125 = getelementptr inbounds float, float* %arrayptr82153, i64 %124
  %arrayref83 = load float, float* %125, align 4
  %126 = fmul float %92, %arrayref83
  %127 = fsub float %arrayref77, %126
  %128 = fmul contract float %127, %127
  %129 = fadd reassoc contract float %value_phi73199, %128
  %130 = add nuw nsw i64 %value_phi74200, 1
  %exitcond203.not = icmp eq i64 %130, %arraylen55
  br i1 %exitcond203.not, label %L199, label %L176

L199:                                             ; preds = %L176, %middle.block, %L162
  %value_phi85 = phi float [ 0.000000e+00, %L162 ], [ %122, %middle.block ], [ %129, %L176 ]
  %131 = fsub float %value_phi85, %value_phi85
  %132 = fcmp uno float %131, 0.000000e+00
  %133 = fcmp ugt float %181, %value_phi85
  %134 = or i1 %133, %132
  br i1 %134, label %L208, label %L210

L208:                                             ; preds = %L199
  %135 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe350, i64 0, i64 2
  store {}* %getfield, {}** %135, align 16
  %136 = call float @j__sqrt_offrange_step_1657({}* nonnull %0, float %arrayref49, i64 signext %value_phi9)
  br label %L325

L210:                                             ; preds = %L199, %L155
  %value_phi87 = phi float [ %95, %L155 ], [ %value_phi85, %L199 ]
  %137 = fcmp uge float %value_phi87, 0.000000e+00
  br i1 %137, label %L215, label %L213

L213:                                             ; preds = %L210
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 136709640595984 to {}*), float %value_phi87) #2
  unreachable

L215:                                             ; preds = %L210
  %138 = call float @llvm.sqrt.f32(float %value_phi87)
  %139 = fsub float %90, %aggregate_load_box.sroa.0.0.copyload
  %140 = fcmp uge float %139, 0.000000e+00
  br i1 %140, label %L222, label %L220

L220:                                             ; preds = %L215
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 136709640595984 to {}*), float %139) #2
  unreachable

L222:                                             ; preds = %L215
  %141 = fadd float %90, %aggregate_load_box.sroa.0.0.copyload
  %142 = fcmp uge float %141, 0.000000e+00
  br i1 %142, label %L229, label %L227

L227:                                             ; preds = %L222
  call void @j_throw_complex_domainerror_1654({}* inttoptr (i64 136709640595984 to {}*), float %141) #2
  unreachable

L229:                                             ; preds = %L222
  %143 = call float @llvm.sqrt.f32(float %139)
  %144 = call float @llvm.sqrt.f32(float %141)
  %145 = fmul float %143, %144
  %146 = fmul float %90, %145
  %147 = fdiv float %138, %146
  %148 = fmul float %aggregate_load_box.sroa.0.0.copyload, %147
  %149 = fcmp oge float %146, 0x3810000000000000
  %150 = fcmp oge float %147, 0x3810000000000000
  %151 = fcmp ole float %147, 0x47EFFFFFE0000000
  %narrow = and i1 %150, %151
  %152 = and i1 %149, %narrow
  %153 = fcmp oge float %148, 0x3810000000000000
  %154 = fcmp ole float %148, 0x47EFFFFFE0000000
  %narrow154 = and i1 %153, %154
  %155 = and i1 %152, %narrow154
  br i1 %155, label %L263, label %L320

L263:                                             ; preds = %L229
  %156 = fneg float %148
  %.inv = fcmp ogt float %93, %156
  %157 = select i1 %.inv, float %93, float %156
  %.inv156 = fcmp olt float %157, %148
  %158 = select i1 %.inv156, float %157, float %148
  %159 = fsub float %93, %158
  %160 = fadd float %159, 0.000000e+00
  br label %L325

L320:                                             ; preds = %L229
  %161 = fpext float %138 to double
  %162 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe350, i64 0, i64 2
  store {}* %getfield, {}** %162, align 16
  %163 = call float @j__sqrt_band_step_1656(float %93, float %90, float %aggregate_load_box.sroa.0.0.copyload, double %161, i64 signext 0)
  br label %L325

L323:                                             ; preds = %idxend46
  %164 = getelementptr inbounds [3 x {}*], [3 x {}*]* %gcframe350, i64 0, i64 2
  store {}* %getfield, {}** %164, align 16
  %165 = call float @j__sqrt_offrange_step_1657({}* nonnull %0, float %arrayref49, i64 signext %value_phi9)
  br label %L325

L325:                                             ; preds = %L323, %L320, %L263, %L208, %L150
  %value_phi57 = phi float [ %136, %L208 ], [ %163, %L320 ], [ %165, %L323 ], [ 0.000000e+00, %L150 ], [ %160, %L263 ]
  %166 = fadd float %value_phi8, %value_phi57
  %.not148.not = icmp eq i64 %value_phi9, %arraylen
  %167 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not148.not, label %L338, label %L31

L338:                                             ; preds = %L325, %L17
  %value_phi61 = phi float [ %value_phi4, %L17 ], [ %166, %L325 ]
  %.not149 = icmp eq i64 %value_phi3, %11
  br i1 %.not149, label %L349, label %L17thread-pre-split

L349:                                             ; preds = %L338, %L17.preheader, %top
  %value_phi64 = phi float [ 0.000000e+00, %top ], [ 0.000000e+00, %L17.preheader ], [ %value_phi61, %L338 ]
  %168 = load {}*, {}** %6, align 8
  %169 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %168, {}** %169, align 8
  ret float %value_phi64

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %170 = bitcast {}* %getfield16 to float**
  %arrayptr143 = load float*, float** %170, align 8
  %171 = getelementptr inbounds float, float* %arrayptr143, i64 %24
  %arrayref = load float, float* %171, align 4
  %172 = fcmp ord float %arrayref, 0.000000e+00
  %173 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr114 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %173, i64 0, i32 1
  %arraylen115 = load i64, i64* %arraylen_ptr114, align 8
  %.not158 = icmp eq i64 %arraylen115, 0
  br i1 %172, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48147 = load float*, float** %18, align 8
  %174 = getelementptr inbounds float, float* %arrayptr48147, i64 %24
  %arrayref49 = load float, float* %174, align 4
  %getfield51 = load atomic {}*, {}** %10 unordered, align 8
  %175 = bitcast {}* %getfield51 to i8*
  %getfield_addr52 = getelementptr inbounds i8, i8* %175, i64 24
  %176 = bitcast i8* %getfield_addr52 to {}**
  %getfield53 = load atomic {}*, {}** %176 unordered, align 8
  %177 = bitcast {}* %getfield53 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr54 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %177, i64 0, i32 1
  %arraylen55 = load i64, i64* %arraylen_ptr54, align 8
  %178 = fsub float %value_phi40, %value_phi40
  %179 = fcmp ord float %178, 0.000000e+00
  %180 = sitofp i64 %arraylen55 to float
  %181 = fmul float %180, 0x3980000000000000
  %182 = fcmp ole float %181, %value_phi40
  %183 = and i1 %179, %182
  %184 = fsub float %value_phi38, %value_phi38
  %185 = fcmp ord float %184, 0.000000e+00
  %186 = fcmp ole float %181, %value_phi38
  %187 = and i1 %185, %186
  %188 = and i1 %183, %187
  br i1 %188, label %L144, label %L323
}
