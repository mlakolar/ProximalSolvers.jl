; Function Attrs: noinline
define float @julia_pass_2120({}* noundef nonnull align 8 dereferenceable(72) %0, {}* noundef nonnull align 16 dereferenceable(40) %1, i64 signext %2) #0 {
top:
  %gcframe493 = alloca [6 x {}*], align 16
  %gcframe493.sub = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 0
  %3 = bitcast [6 x {}*]* %gcframe493 to i8*
  call void @llvm.memset.p0i8.i64(i8* align 16 %3, i8 0, i64 48, i1 true)
  %4 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 3
  %5 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 2
  %newstruct59 = alloca { [1 x [1 x i64]], i64 }, align 8
  %aggregate_load_box = alloca { float }, align 8
  %6 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %7 = alloca { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }, align 8
  %thread_ptr = call i8* asm "movq %fs:0, $0", "=r"() #13
  %tls_ppgcstack = getelementptr i8, i8* %thread_ptr, i64 -8
  %8 = bitcast i8* %tls_ppgcstack to {}****
  %tls_pgcstack = load {}***, {}**** %8, align 8
  %9 = bitcast [6 x {}*]* %gcframe493 to i64*
  store i64 16, i64* %9, align 16
  %10 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 1
  %11 = bitcast {}** %10 to {}***
  %12 = load {}**, {}*** %tls_pgcstack, align 8
  store {}** %12, {}*** %11, align 8
  %13 = bitcast {}*** %tls_pgcstack to {}***
  store {}** %gcframe493.sub, {}*** %13, align 8
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
  %value_phi8 = phi float [ %205, %L362 ], [ %value_phi4, %L17 ]
  %value_phi9 = phi i64 [ %206, %L362 ], [ 1, %L17 ]
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
  br label %vector.body431

vector.body431:                                   ; preds = %vector.body431, %vector.ph426
  %index432 = phi i64 [ 0, %vector.ph426 ], [ %index.next438, %vector.body431 ]
  %vec.phi433 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426 ], [ %44, %vector.body431 ]
  %vec.phi434 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426 ], [ %46, %vector.body431 ]
  %vec.phi435 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph426 ], [ %48, %vector.body431 ]
  %38 = add i64 %35, %index432
  %39 = getelementptr inbounds float, float* %arrayptr27170, i64 %38
  %40 = bitcast float* %39 to <8 x float>*
  %wide.load436 = load <8 x float>, <8 x float>* %40, align 4
  %41 = getelementptr inbounds float, float* %arrayptr30171, i64 %index432
  %42 = bitcast float* %41 to <8 x float>*
  %wide.load437 = load <8 x float>, <8 x float>* %42, align 4
  %43 = fmul contract <8 x float> %wide.load436, %wide.load436
  %44 = fadd reassoc contract <8 x float> %vec.phi433, %43
  %45 = fmul contract <8 x float> %wide.load436, %wide.load437
  %46 = fadd reassoc contract <8 x float> %vec.phi434, %45
  %47 = fmul contract <8 x float> %wide.load437, %wide.load437
  %48 = fadd reassoc contract <8 x float> %vec.phi435, %47
  %index.next438 = add nuw i64 %index432, 8
  %49 = icmp eq i64 %index.next438, %n.vec428
  br i1 %49, label %middle.block423, label %vector.body431

middle.block423:                                  ; preds = %vector.body431
  %50 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %48)
  %51 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %46)
  %52 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %44)
  %cmp.n430 = icmp eq i64 %arraylen129, %n.vec428
  br i1 %cmp.n430, label %L124, label %scalar.ph424

scalar.ph424:                                     ; preds = %middle.block423, %L54.lr.ph
  %bc.resume.val429 = phi i64 [ %n.vec428, %middle.block423 ], [ 0, %L54.lr.ph ]
  %bc.merge.rdx439 = phi float [ %52, %middle.block423 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx440 = phi float [ %51, %middle.block423 ], [ 0.000000e+00, %L54.lr.ph ]
  %bc.merge.rdx441 = phi float [ %50, %middle.block423 ], [ 0.000000e+00, %L54.lr.ph ]
  br label %L54

L54:                                              ; preds = %L54, %scalar.ph424
  %value_phi25223 = phi float [ %bc.merge.rdx439, %scalar.ph424 ], [ %57, %L54 ]
  %value_phi24222 = phi i64 [ %bc.resume.val429, %scalar.ph424 ], [ %62, %L54 ]
  %value_phi23221 = phi float [ %bc.merge.rdx440, %scalar.ph424 ], [ %59, %L54 ]
  %value_phi22220 = phi float [ %bc.merge.rdx441, %scalar.ph424 ], [ %61, %L54 ]
  %53 = add i64 %35, %value_phi24222
  %54 = getelementptr inbounds float, float* %arrayptr27170, i64 %53
  %arrayref28 = load float, float* %54, align 4
  %55 = getelementptr inbounds float, float* %arrayptr30171, i64 %value_phi24222
  %arrayref31 = load float, float* %55, align 4
  %56 = fmul contract float %arrayref28, %arrayref28
  %57 = fadd reassoc contract float %value_phi25223, %56
  %58 = fmul contract float %arrayref28, %arrayref31
  %59 = fadd reassoc contract float %value_phi23221, %58
  %60 = fmul contract float %arrayref31, %arrayref31
  %61 = fadd reassoc contract float %value_phi22220, %60
  %62 = add nuw nsw i64 %value_phi24222, 1
  %exitcond.not = icmp eq i64 %62, %arraylen129
  br i1 %exitcond.not, label %L124, label %L54

L83:                                              ; preds = %idxend
  br i1 %.not184, label %L124, label %L96.lr.ph

L96.lr.ph:                                        ; preds = %L83
  %63 = bitcast {}* %getfield12 to {}**
  %arraysize_ptr135 = getelementptr inbounds {}*, {}** %63, i64 3
  %64 = bitcast {}** %arraysize_ptr135 to i64*
  %arraysize136 = load i64, i64* %64, align 8
  %65 = mul i64 %arraysize136, %31
  %66 = bitcast {}* %getfield12 to float**
  %arrayptr139186 = load float*, float** %66, align 8
  %67 = bitcast {}* %getfield14 to float**
  %arrayptr142187 = load float*, float** %67, align 8
  %min.iters.check402 = icmp ult i64 %arraylen129, 16
  br i1 %min.iters.check402, label %scalar.ph401, label %vector.ph403

vector.ph403:                                     ; preds = %L96.lr.ph
  %n.vec405 = and i64 %arraylen129, 9223372036854775792
  br label %vector.body408

vector.body408:                                   ; preds = %vector.body408, %vector.ph403
  %index409 = phi i64 [ 0, %vector.ph403 ], [ %index.next418, %vector.body408 ]
  %vec.phi410 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %79, %vector.body408 ]
  %vec.phi411 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %80, %vector.body408 ]
  %vec.phi412 = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %83, %vector.body408 ]
  %vec.phi413 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph403 ], [ %84, %vector.body408 ]
  %68 = add i64 %65, %index409
  %69 = getelementptr inbounds float, float* %arrayptr139186, i64 %68
  %70 = bitcast float* %69 to <8 x float>*
  %wide.load414 = load <8 x float>, <8 x float>* %70, align 4
  %71 = getelementptr inbounds float, float* %69, i64 8
  %72 = bitcast float* %71 to <8 x float>*
  %wide.load415 = load <8 x float>, <8 x float>* %72, align 4
  %73 = getelementptr inbounds float, float* %arrayptr142187, i64 %index409
  %74 = bitcast float* %73 to <8 x float>*
  %wide.load416 = load <8 x float>, <8 x float>* %74, align 4
  %75 = getelementptr inbounds float, float* %73, i64 8
  %76 = bitcast float* %75 to <8 x float>*
  %wide.load417 = load <8 x float>, <8 x float>* %76, align 4
  %77 = fmul contract <8 x float> %wide.load414, %wide.load416
  %78 = fmul contract <8 x float> %wide.load415, %wide.load417
  %79 = fadd reassoc contract <8 x float> %vec.phi410, %77
  %80 = fadd reassoc contract <8 x float> %vec.phi411, %78
  %81 = fmul contract <8 x float> %wide.load416, %wide.load416
  %82 = fmul contract <8 x float> %wide.load417, %wide.load417
  %83 = fadd reassoc contract <8 x float> %vec.phi412, %81
  %84 = fadd reassoc contract <8 x float> %vec.phi413, %82
  %index.next418 = add nuw i64 %index409, 16
  %85 = icmp eq i64 %index.next418, %n.vec405
  br i1 %85, label %middle.block400, label %vector.body408

middle.block400:                                  ; preds = %vector.body408
  %bin.rdx421 = fadd reassoc contract <8 x float> %84, %83
  %86 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx421)
  %bin.rdx419 = fadd reassoc contract <8 x float> %80, %79
  %87 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx419)
  %cmp.n407 = icmp eq i64 %arraylen129, %n.vec405
  br i1 %cmp.n407, label %L124, label %scalar.ph401

scalar.ph401:                                     ; preds = %middle.block400, %L96.lr.ph
  %bc.resume.val406 = phi i64 [ %n.vec405, %middle.block400 ], [ 0, %L96.lr.ph ]
  %bc.merge.rdx420 = phi float [ %87, %middle.block400 ], [ 0.000000e+00, %L96.lr.ph ]
  %bc.merge.rdx422 = phi float [ %86, %middle.block400 ], [ 0.000000e+00, %L96.lr.ph ]
  br label %L96

L96:                                              ; preds = %L96, %scalar.ph401
  %value_phi134229 = phi i64 [ %bc.resume.val406, %scalar.ph401 ], [ %95, %L96 ]
  %value_phi133228 = phi float [ %bc.merge.rdx420, %scalar.ph401 ], [ %92, %L96 ]
  %value_phi132227 = phi float [ %bc.merge.rdx422, %scalar.ph401 ], [ %94, %L96 ]
  %88 = add i64 %65, %value_phi134229
  %89 = getelementptr inbounds float, float* %arrayptr139186, i64 %88
  %arrayref140 = load float, float* %89, align 4
  %90 = getelementptr inbounds float, float* %arrayptr142187, i64 %value_phi134229
  %arrayref143 = load float, float* %90, align 4
  %91 = fmul contract float %arrayref140, %arrayref143
  %92 = fadd reassoc contract float %value_phi133228, %91
  %93 = fmul contract float %arrayref143, %arrayref143
  %94 = fadd reassoc contract float %value_phi132227, %93
  %95 = add nuw nsw i64 %value_phi134229, 1
  %exitcond284.not = icmp eq i64 %95, %arraylen129
  br i1 %exitcond284.not, label %L124, label %L96

L124:                                             ; preds = %L96, %middle.block400, %L83, %L54, %middle.block423, %L40
  %value_phi38 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %86, %middle.block400 ], [ %50, %middle.block423 ], [ %94, %L96 ], [ %61, %L54 ]
  %value_phi39 = phi float [ 0.000000e+00, %L40 ], [ 0.000000e+00, %L83 ], [ %87, %middle.block400 ], [ %51, %middle.block423 ], [ %92, %L96 ], [ %59, %L54 ]
  %value_phi40 = phi float [ 0.000000e+00, %L40 ], [ %arrayref, %L83 ], [ %arrayref, %middle.block400 ], [ %52, %middle.block423 ], [ %arrayref, %L96 ], [ %57, %L54 ]
  %arraylen42 = load i64, i64* %arraylen_ptr, align 8
  %inbounds43 = icmp ult i64 %31, %arraylen42
  br i1 %inbounds43, label %idxend46, label %oob44

L145:                                             ; preds = %idxend46
  store i64 %arraysize55, i64* %memcpy_refined_dst, align 8
  store i64 %value_phi9, i64* %23, align 8
  %96 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 4
  store {}* %getfield53, {}** %96, align 16
  call void @j_throw_boundserror_2127({}* nonnull %getfield53, { [1 x [1 x i64]], i64 }* nocapture readonly %newstruct59) #2
  unreachable

L148:                                             ; preds = %idxend46
  %97 = mul i64 %arraysize55, %31
  %98 = bitcast {}* %getfield51 to i8*
  %getfield_addr71 = getelementptr inbounds i8, i8* %98, i64 24
  %99 = bitcast i8* %getfield_addr71 to {}**
  %getfield72 = load atomic {}*, {}** %99 unordered, align 8
  %100 = load i32, i32* %26, align 1
  store i32 %100, i32* %27, align 8
  %101 = bitcast {}* %getfield72 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr73 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %101, i64 0, i32 1
  %arraylen74 = load i64, i64* %arraylen_ptr73, align 8
  %102 = fsub float %value_phi40, %value_phi40
  %103 = fcmp ord float %102, 0.000000e+00
  %104 = sitofp i64 %arraylen74 to float
  %105 = fmul float %104, 0x3980000000000000
  %106 = fcmp ole float %105, %value_phi40
  %107 = and i1 %103, %106
  %108 = fsub float %value_phi38, %value_phi38
  %109 = fcmp ord float %108, 0.000000e+00
  %110 = fcmp ole float %105, %value_phi38
  %111 = and i1 %109, %110
  %112 = and i1 %107, %111
  %113 = bitcast i32 %100 to float
  br i1 %112, label %L179, label %L358

L179:                                             ; preds = %L148
  %114 = fcmp uge float %value_phi40, 0.000000e+00
  br i1 %114, label %L184, label %L182

L182:                                             ; preds = %L179
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 136709640595984 to {}*), float %value_phi40) #2
  unreachable

L184:                                             ; preds = %L179
  %115 = call float @llvm.sqrt.f32(float %value_phi40)
  %116 = fcmp ugt float %115, %113
  br i1 %116, label %L189, label %L362

L189:                                             ; preds = %L184
  %117 = fdiv float %value_phi39, %value_phi40
  %118 = fadd float %117, %arrayref49
  %119 = fmul float %value_phi39, %117
  %120 = fsub float %value_phi38, %119
  %121 = fmul float %value_phi38, 6.250000e-02
  %122 = fcmp uge float %120, %121
  br i1 %122, label %L245, label %L196

L196:                                             ; preds = %L189
  %.not176 = icmp eq i64 %arraylen74, 0
  br i1 %.not176, label %L250, label %L208.lr.ph

L208.lr.ph:                                       ; preds = %L196
  %123 = bitcast {}* %getfield72 to float**
  %arrayptr92178 = load float*, float** %123, align 8
  %124 = bitcast {}* %getfield53 to float**
  %arrayptr96179 = load float*, float** %124, align 8
  %min.iters.check = icmp ult i64 %arraylen74, 16
  br i1 %min.iters.check, label %scalar.ph, label %vector.ph

vector.ph:                                        ; preds = %L208.lr.ph
  %n.vec = and i64 %arraylen74, 9223372036854775792
  %broadcast.splatinsert = insertelement <8 x float> poison, float %117, i64 0
  %broadcast.splat = shufflevector <8 x float> %broadcast.splatinsert, <8 x float> poison, <8 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %vec.phi = phi <8 x float> [ <float 0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %140, %vector.body ]
  %vec.phi394 = phi <8 x float> [ <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %vector.ph ], [ %141, %vector.body ]
  %125 = getelementptr inbounds float, float* %arrayptr92178, i64 %index
  %126 = bitcast float* %125 to <8 x float>*
  %wide.load = load <8 x float>, <8 x float>* %126, align 4
  %127 = getelementptr inbounds float, float* %125, i64 8
  %128 = bitcast float* %127 to <8 x float>*
  %wide.load395 = load <8 x float>, <8 x float>* %128, align 4
  %129 = add i64 %index, %97
  %130 = getelementptr inbounds float, float* %arrayptr96179, i64 %129
  %131 = bitcast float* %130 to <8 x float>*
  %wide.load396 = load <8 x float>, <8 x float>* %131, align 4
  %132 = getelementptr inbounds float, float* %130, i64 8
  %133 = bitcast float* %132 to <8 x float>*
  %wide.load397 = load <8 x float>, <8 x float>* %133, align 4
  %134 = fmul <8 x float> %broadcast.splat, %wide.load396
  %135 = fmul <8 x float> %broadcast.splat, %wide.load397
  %136 = fsub <8 x float> %wide.load, %134
  %137 = fsub <8 x float> %wide.load395, %135
  %138 = fmul contract <8 x float> %136, %136
  %139 = fmul contract <8 x float> %137, %137
  %140 = fadd reassoc contract <8 x float> %vec.phi, %138
  %141 = fadd reassoc contract <8 x float> %vec.phi394, %139
  %index.next = add nuw i64 %index, 16
  %142 = icmp eq i64 %index.next, %n.vec
  br i1 %142, label %middle.block, label %vector.body

middle.block:                                     ; preds = %vector.body
  %bin.rdx = fadd reassoc contract <8 x float> %141, %140
  %143 = call reassoc contract float @llvm.vector.reduce.fadd.v8f32(float -0.000000e+00, <8 x float> %bin.rdx)
  %cmp.n = icmp eq i64 %arraylen74, %n.vec
  br i1 %cmp.n, label %L245, label %scalar.ph

scalar.ph:                                        ; preds = %middle.block, %L208.lr.ph
  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0, %L208.lr.ph ]
  %bc.merge.rdx = phi float [ %143, %middle.block ], [ 0.000000e+00, %L208.lr.ph ]
  br label %L208

L208:                                             ; preds = %L208, %scalar.ph
  %value_phi90234 = phi i64 [ %bc.resume.val, %scalar.ph ], [ %151, %L208 ]
  %value_phi89233 = phi float [ %bc.merge.rdx, %scalar.ph ], [ %150, %L208 ]
  %144 = getelementptr inbounds float, float* %arrayptr92178, i64 %value_phi90234
  %arrayref93 = load float, float* %144, align 4
  %145 = add i64 %value_phi90234, %97
  %146 = getelementptr inbounds float, float* %arrayptr96179, i64 %145
  %arrayref97 = load float, float* %146, align 4
  %147 = fmul float %117, %arrayref97
  %148 = fsub float %arrayref93, %147
  %149 = fmul contract float %148, %148
  %150 = fadd reassoc contract float %value_phi89233, %149
  %151 = add nuw nsw i64 %value_phi90234, 1
  %exitcond285.not = icmp eq i64 %151, %arraylen74
  br i1 %exitcond285.not, label %L245, label %L208

L245:                                             ; preds = %L208, %middle.block, %L189
  %value_phi102 = phi float [ %120, %L189 ], [ %143, %middle.block ], [ %150, %L208 ]
  %152 = fcmp uge float %value_phi102, 0.000000e+00
  br i1 %152, label %L250, label %L248

L248:                                             ; preds = %L245
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 136709640595984 to {}*), float %value_phi102) #2
  unreachable

L250:                                             ; preds = %L245, %L196
  %value_phi102189 = phi float [ %value_phi102, %L245 ], [ 0.000000e+00, %L196 ]
  %153 = call float @llvm.sqrt.f32(float %value_phi102189)
  %154 = fsub float %115, %113
  %155 = fcmp uge float %154, 0.000000e+00
  br i1 %155, label %L257, label %L255

L255:                                             ; preds = %L250
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 136709640595984 to {}*), float %154) #2
  unreachable

L257:                                             ; preds = %L250
  %156 = fadd float %115, %113
  %157 = fcmp uge float %156, 0.000000e+00
  br i1 %157, label %L264, label %L262

L262:                                             ; preds = %L257
  call void @j_throw_complex_domainerror_2123({}* inttoptr (i64 136709640595984 to {}*), float %156) #2
  unreachable

L264:                                             ; preds = %L257
  %158 = call float @llvm.sqrt.f32(float %154)
  %159 = call float @llvm.sqrt.f32(float %156)
  %160 = fmul float %158, %159
  %161 = fmul float %115, %160
  %162 = fdiv float %153, %161
  %163 = fmul float %162, %113
  %164 = fcmp oge float %161, 0x3810000000000000
  %165 = fcmp oeq float %153, 0.000000e+00
  %166 = fcmp oge float %162, 0x3810000000000000
  %167 = fcmp ole float %162, 0x47EFFFFFE0000000
  %narrow = and i1 %166, %167
  %168 = fcmp oge float %163, 0x3810000000000000
  %169 = fcmp ole float %163, 0x47EFFFFFE0000000
  %narrow180 = and i1 %168, %169
  %170 = and i1 %narrow, %narrow180
  %171 = or i1 %165, %170
  %172 = and i1 %164, %171
  br i1 %172, label %L288, label %L356

L288:                                             ; preds = %L264
  %173 = fcmp ult float %163, 0x3810000000000000
  %174 = fcmp ugt float %163, 0x47EFFFFFE0000000
  %175 = or i1 %173, %174
  br i1 %175, label %L323, label %L299

L299:                                             ; preds = %L288
  %176 = fneg float %163
  %.inv = fcmp ogt float %118, %176
  %177 = select i1 %.inv, float %118, float %176
  %.inv182 = fcmp olt float %177, %163
  %178 = select i1 %.inv182, float %177, float %163
  %179 = fsub float %118, %178
  %180 = fadd float %179, 0.000000e+00
  br label %L362

L323:                                             ; preds = %L288
  %181 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 5
  store {}* %getfield, {}** %181, align 8
  %182 = call float @j__exceptional_product_2125(float %162, float %113, float 1.000000e+00)
  %183 = fsub float %118, %182
  %bitcast_coercion = bitcast float %183 to i32
  %184 = icmp sgt i32 %bitcast_coercion, -1
  %185 = select i1 %184, float %183, float 0.000000e+00
  %186 = fcmp ord float %183, 0.000000e+00
  %187 = select i1 %186, float %185, float %183
  %188 = fadd float %118, %182
  %bitcast_coercion121 = bitcast float %188 to i32
  %189 = icmp sgt i32 %bitcast_coercion121, -1
  %190 = fcmp ord float %188, 0.000000e+00
  %191 = and i1 %190, %189
  %192 = select i1 %191, float 0.000000e+00, float %188
  %193 = fadd float %187, %192
  %194 = fcmp ult float %162, 0.000000e+00
  %195 = call float @llvm.fabs.f32(float %113)
  %196 = bitcast float %195 to i32
  %197 = icmp ne i32 %196, 2139095040
  %ifelse_cond125 = or i1 %194, %197
  %198 = select i1 %ifelse_cond125, float %193, float 0.000000e+00
  br label %L362

L356:                                             ; preds = %L264
  store {}* %getfield53, {}** %5, align 16
  store {}* %getfield53, {}** %.fca.0.gep152, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep154, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep156, align 8
  store i64 %97, i64* %.fca.2.gep158, align 8
  store i64 1, i64* %.fca.3.gep160, align 8
  %199 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 5
  store {}* %getfield, {}** %199, align 8
  %200 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 4
  store {}* %getfield72, {}** %200, align 16
  %201 = call float @j__sqrt_cold_2126({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %6, {}* nonnull %getfield72, { float }* nocapture readonly %aggregate_load_box, float %arrayref49, float %value_phi40, i64 signext %value_phi9)
  br label %L362

L358:                                             ; preds = %L148
  store {}* %getfield53, {}** %4, align 8
  store {}* %getfield53, {}** %.fca.0.gep, align 8
  store i64 %arraysize55, i64* %.fca.1.0.0.0.gep, align 8
  store i64 %value_phi9, i64* %.fca.1.1.gep, align 8
  store i64 %97, i64* %.fca.2.gep, align 8
  store i64 1, i64* %.fca.3.gep, align 8
  %202 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 5
  store {}* %getfield, {}** %202, align 8
  %203 = getelementptr inbounds [6 x {}*], [6 x {}*]* %gcframe493, i64 0, i64 4
  store {}* %getfield72, {}** %203, align 16
  %204 = call float @j__sqrt_cold_2126({}* nonnull %0, { {}*, { [1 x [1 x i64]], i64 }, i64, i64 }* nocapture readonly %7, {}* nonnull %getfield72, { float }* nocapture readonly %aggregate_load_box, float %arrayref49, float %value_phi40, i64 signext %value_phi9)
  br label %L362

L362:                                             ; preds = %L358, %L356, %L323, %L299, %L184
  %value_phi77 = phi float [ %201, %L356 ], [ %204, %L358 ], [ 0.000000e+00, %L184 ], [ %180, %L299 ], [ %198, %L323 ]
  %205 = fadd float %value_phi8, %value_phi77
  %.not174.not = icmp eq i64 %value_phi9, %arraylen
  %206 = add nuw nsw i64 %value_phi9, 1
  br i1 %.not174.not, label %L374, label %L31

L374:                                             ; preds = %L362, %L17
  %value_phi9.lcssa263274 = phi i64 [ %value_phi9.lcssa263275, %L17 ], [ %arraylen, %L362 ]
  %arraysize55.lcssa248265 = phi i64 [ %arraysize55.lcssa248266, %L17 ], [ %arraysize55, %L362 ]
  %value_phi81 = phi float [ %value_phi4, %L17 ], [ %205, %L362 ]
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
  %207 = load {}*, {}** %10, align 8
  %208 = bitcast {}*** %tls_pgcstack to {}**
  store {}* %207, {}** %208, align 8
  ret float %value_phi84

oob:                                              ; preds = %L31
  %errorbox = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox, align 8
  call void @ijl_bounds_error_ints({}* %getfield16, i64* nonnull %errorbox, i64 1)
  unreachable

idxend:                                           ; preds = %L31
  %209 = bitcast {}* %getfield16 to float**
  %arrayptr168 = load float*, float** %209, align 8
  %210 = getelementptr inbounds float, float* %arrayptr168, i64 %31
  %arrayref = load float, float* %210, align 4
  %211 = fcmp ord float %arrayref, 0.000000e+00
  %212 = bitcast {}* %getfield14 to { i8*, i64, i16, i16, i32 }*
  %arraylen_ptr128 = getelementptr inbounds { i8*, i64, i16, i16, i32 }, { i8*, i64, i16, i16, i32 }* %212, i64 0, i32 1
  %arraylen129 = load i64, i64* %arraylen_ptr128, align 8
  %.not184 = icmp eq i64 %arraylen129, 0
  br i1 %211, label %L83, label %L40

oob44:                                            ; preds = %L124
  %errorbox45 = alloca i64, align 8
  store i64 %value_phi9, i64* %errorbox45, align 8
  call void @ijl_bounds_error_ints({}* %1, i64* nonnull %errorbox45, i64 1)
  unreachable

idxend46:                                         ; preds = %L124
  %arrayptr48172 = load float*, float** %22, align 8
  %213 = getelementptr inbounds float, float* %arrayptr48172, i64 %31
  %arrayref49 = load float, float* %213, align 4
  %getfield51 = load atomic {}*, {}** %14 unordered, align 8
  %214 = bitcast {}* %getfield51 to {}**
  %getfield53 = load atomic {}*, {}** %214 unordered, align 8
  %215 = bitcast {}* %getfield53 to {}**
  %arraysize_ptr54 = getelementptr inbounds {}*, {}** %215, i64 3
  %216 = bitcast {}** %arraysize_ptr54 to i64*
  %arraysize55 = load i64, i64* %216, align 8
  %arraysize_ptr60 = getelementptr inbounds {}*, {}** %215, i64 4
  %217 = bitcast {}** %arraysize_ptr60 to i64*
  %arraysize61 = load i64, i64* %217, align 8
  %.not173 = icmp ult i64 %31, %arraysize61
  br i1 %.not173, label %L148, label %L145
}
