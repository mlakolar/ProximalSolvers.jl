	.file	"norm_diff"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function julia_norm_diff_1274
.LCPI0_0:
	.quad	0x4000000000000000              # double 2
.LCPI0_1:
	.quad	0x7ff0000000000000              # double +Inf
.LCPI0_2:
	.quad	0x7fffffffffffffff              # double NaN
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI0_3:
	.quad	0x7fffffffffffffff              # double NaN
	.quad	0x7fffffffffffffff              # double NaN
	.section	.ltext,"axl",@progbits
	.globl	julia_norm_diff_1274
	.p2align	4
	.type	julia_norm_diff_1274,@function
julia_norm_diff_1274:                   # @julia_norm_diff_1274
; Function Signature: norm_diff(Array{Float64, 1}, Array{Float64, 1}, Float64)
# %bb.0:                                # %top
	#DEBUG_VALUE: norm_diff:A <- [$rdi+0]
	#DEBUG_VALUE: norm_diff:B <- [$rsi+0]
	#DEBUG_VALUE: norm_diff:p <- $xmm0
	push	rbp
	mov	rbp, rsp
	push	r14
	push	rbx
	sub	rsp, 32
	vxorpd	xmm1, xmm1, xmm1
	vmovapd	xmmword ptr [rbp - 48], xmm1
	mov	qword ptr [rbp - 32], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	r14, qword ptr [rax - 8]
	mov	qword ptr [rbp - 48], 4
	mov	rax, qword ptr [r14]
	mov	qword ptr [rbp - 40], rax
	lea	rax, [rbp - 48]
	mov	qword ptr [r14], rax
	mov	rax, qword ptr [rdi + 16]
	cmp	rax, qword ptr [rsi + 16]
	jne	.LBB0_31
# %bb.1:                                # %L19
	movabs	rcx, offset .LCPI0_0
	vucomisd	xmm0, qword ptr [rcx]
	jne	.LBB0_4
	jnp	.LBB0_2
.LBB0_4:                                # %L26
	movabs	rcx, offset .LCPI0_1
	vucomisd	xmm0, qword ptr [rcx]
	jb	.LBB0_30
# %bb.5:                                # %L49
	test	rax, rax
	jle	.LBB0_6
# %bb.7:                                # %iter.check
	mov	rcx, qword ptr [rdi]
	mov	rdx, qword ptr [rsi]
	cmp	rax, 4
	jae	.LBB0_9
# %bb.8:
	vxorpd	xmm0, xmm0, xmm0
	mov	r9d, 1
	jmp	.LBB0_25
.LBB0_2:                                # %L24
	movabs	rax, offset j__norm_diff2_1277
	call	rax
	jmp	.LBB0_3
.LBB0_6:
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_3
.LBB0_9:                                # %vector.main.loop.iter.check
	movabs	rsi, 9223372036854775792
	movabs	r8, offset .LCPI0_2
	cmp	rax, 16
	jae	.LBB0_15
# %bb.10:
	vxorpd	xmm0, xmm0, xmm0
	xor	edi, edi
	jmp	.LBB0_11
.LBB0_15:                               # %vector.ph
	mov	rdi, rax
	and	rdi, rsi
	vxorpd	xmm1, xmm1, xmm1
	xor	r9d, r9d
	vbroadcastsd	ymm3, qword ptr [r8]
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4
.LBB0_16:                               # %vector.body
                                        # =>This Inner Loop Header: Depth=1
	vmovupd	ymm5, ymmword ptr [rcx + 8*r9]
	vmovupd	ymm6, ymmword ptr [rcx + 8*r9 + 32]
	vmovupd	ymm7, ymmword ptr [rcx + 8*r9 + 64]
	vmovupd	ymm8, ymmword ptr [rcx + 8*r9 + 96]
	vsubpd	ymm5, ymm5, ymmword ptr [rdx + 8*r9]
	vsubpd	ymm6, ymm6, ymmword ptr [rdx + 8*r9 + 32]
	vsubpd	ymm7, ymm7, ymmword ptr [rdx + 8*r9 + 64]
	vsubpd	ymm8, ymm8, ymmword ptr [rdx + 8*r9 + 96]
	vandpd	ymm5, ymm5, ymm3
	vblendvpd	ymm9, ymm1, ymm5, ymm1
	vandpd	ymm6, ymm6, ymm3
	vblendvpd	ymm1, ymm5, ymm1, ymm1
	vmaxpd	ymm5, ymm1, ymm9
	vcmpunordpd	ymm9, ymm1, ymm1
	vblendvpd	ymm1, ymm5, ymm1, ymm9
	vblendvpd	ymm5, ymm4, ymm6, ymm4
	vandpd	ymm7, ymm7, ymm3
	vblendvpd	ymm4, ymm6, ymm4, ymm4
	vmaxpd	ymm5, ymm4, ymm5
	vcmpunordpd	ymm6, ymm4, ymm4
	vblendvpd	ymm4, ymm5, ymm4, ymm6
	vblendvpd	ymm5, ymm2, ymm7, ymm2
	vandpd	ymm6, ymm8, ymm3
	vblendvpd	ymm2, ymm7, ymm2, ymm2
	vmaxpd	ymm5, ymm2, ymm5
	vcmpunordpd	ymm7, ymm2, ymm2
	vblendvpd	ymm2, ymm5, ymm2, ymm7
	vblendvpd	ymm5, ymm0, ymm6, ymm0
	vblendvpd	ymm0, ymm6, ymm0, ymm0
	vmaxpd	ymm5, ymm0, ymm5
	vcmpunordpd	ymm6, ymm0, ymm0
	vblendvpd	ymm0, ymm5, ymm0, ymm6
	add	r9, 16
	cmp	rdi, r9
	jne	.LBB0_16
# %bb.17:                               # %middle.block
	vblendvpd	ymm3, ymm1, ymm4, ymm1
	vblendvpd	ymm1, ymm4, ymm1, ymm1
	vmaxpd	ymm3, ymm1, ymm3
	vcmpunordpd	ymm4, ymm1, ymm1
	vblendvpd	ymm1, ymm3, ymm1, ymm4
	vblendvpd	ymm3, ymm1, ymm2, ymm1
	vblendvpd	ymm1, ymm2, ymm1, ymm1
	vmaxpd	ymm2, ymm1, ymm3
	vcmpunordpd	ymm3, ymm1, ymm1
	vblendvpd	ymm1, ymm2, ymm1, ymm3
	vblendvpd	ymm2, ymm1, ymm0, ymm1
	vblendvpd	ymm0, ymm0, ymm1, ymm1
	vmaxpd	ymm1, ymm0, ymm2
	vcmpunordpd	ymm2, ymm0, ymm0
	vblendvpd	ymm0, ymm1, ymm0, ymm2
	vextractf128	xmm1, ymm0, 1
	vblendvpd	xmm2, xmm0, xmm1, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm0
	vmaxpd	xmm1, xmm0, xmm2
	vcmpunordpd	xmm2, xmm0, xmm0
	vblendvpd	xmm1, xmm1, xmm0, xmm2
	vshufpd	xmm0, xmm1, xmm1, 1             # xmm0 = xmm1[1,0]
	vmovq	r9, xmm1
	test	r9, r9
	js	.LBB0_18
# %bb.19:                               # %middle.block
	vmovapd	xmm2, xmm1
	jmp	.LBB0_20
.LBB0_18:
	vmovapd	xmm2, xmm0
	vmovapd	xmm0, xmm1
.LBB0_20:                               # %middle.block
	vmaxsd	xmm1, xmm0, xmm2
	vcmpunordsd	xmm2, xmm0, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rdi
	je	.LBB0_3
# %bb.21:                               # %vec.epilog.iter.check
	test	al, 12
	je	.LBB0_22
.LBB0_11:                               # %vec.epilog.ph
	add	rsi, 12
	and	rsi, rax
	mov	r9, rsi
	or	r9, 1
	vbroadcastsd	ymm0, xmm0
	vbroadcastsd	ymm1, qword ptr [r8]
	.p2align	4
.LBB0_12:                               # %vec.epilog.vector.body
                                        # =>This Inner Loop Header: Depth=1
	vmovupd	ymm2, ymmword ptr [rcx + 8*rdi]
	vsubpd	ymm2, ymm2, ymmword ptr [rdx + 8*rdi]
	vandpd	ymm2, ymm2, ymm1
	vblendvpd	ymm3, ymm0, ymm2, ymm0
	vblendvpd	ymm0, ymm2, ymm0, ymm0
	vmaxpd	ymm2, ymm0, ymm3
	vcmpunordpd	ymm3, ymm0, ymm0
	vblendvpd	ymm0, ymm2, ymm0, ymm3
	add	rdi, 4
	cmp	rsi, rdi
	jne	.LBB0_12
# %bb.13:                               # %vec.epilog.middle.block
	vextractf128	xmm1, ymm0, 1
	vblendvpd	xmm2, xmm0, xmm1, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm0
	vmaxpd	xmm1, xmm0, xmm2
	vcmpunordpd	xmm2, xmm0, xmm0
	vblendvpd	xmm1, xmm1, xmm0, xmm2
	vshufpd	xmm0, xmm1, xmm1, 1             # xmm0 = xmm1[1,0]
	vmovq	rdi, xmm1
	test	rdi, rdi
	js	.LBB0_14
# %bb.23:                               # %vec.epilog.middle.block
	vmovapd	xmm2, xmm1
	jmp	.LBB0_24
.LBB0_14:
	vmovapd	xmm2, xmm0
	vmovapd	xmm0, xmm1
.LBB0_24:                               # %vec.epilog.middle.block
	vmaxsd	xmm1, xmm0, xmm2
	vcmpunordsd	xmm2, xmm0, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rsi
	jne	.LBB0_25
.LBB0_3:                                # %common.ret
	mov	rax, qword ptr [rbp - 40]
	mov	qword ptr [r14], rax
	add	rsp, 32
	pop	rbx
	pop	r14
	pop	rbp
	vzeroupper
	ret
.LBB0_22:
	or	rdi, 1
	mov	r9, rdi
.LBB0_25:                               # %L58.preheader
	dec	r9
	movabs	rsi, offset .LCPI0_3
	vmovapd	xmm1, xmmword ptr [rsi]
	jmp	.LBB0_26
	.p2align	4
.LBB0_28:                               # %L58
                                        #   in Loop: Header=BB0_26 Depth=1
	vmovapd	xmm3, xmm0
.LBB0_29:                               # %L58
                                        #   in Loop: Header=BB0_26 Depth=1
	vmaxsd	xmm0, xmm2, xmm3
	vcmpunordsd	xmm3, xmm2, xmm2
	vblendvpd	xmm0, xmm0, xmm2, xmm3
	inc	r9
	cmp	rax, r9
	je	.LBB0_3
.LBB0_26:                               # %L58
                                        # =>This Inner Loop Header: Depth=1
	vmovsd	xmm2, qword ptr [rcx + 8*r9]    # xmm2 = mem[0],zero
	vsubsd	xmm2, xmm2, qword ptr [rdx + 8*r9]
	vandpd	xmm2, xmm2, xmm1
	vmovq	rsi, xmm0
	test	rsi, rsi
	jns	.LBB0_28
# %bb.27:                               #   in Loop: Header=BB0_26 Depth=1
	vmovapd	xmm3, xmm2
	vmovapd	xmm2, xmm0
	jmp	.LBB0_29
.LBB0_31:                               # %L116
	movabs	rdi, offset ".Ljl_global#1285.jit"
	movabs	rax, offset j_DimensionMismatch_1284
	call	rax
	mov	rbx, rax
	mov	qword ptr [rbp - 32], rax
	mov	rdi, qword ptr [r14 + 16]
	movabs	rax, offset ijl_gc_small_alloc
	movabs	r14, 128967350944432
	mov	esi, 360
	mov	edx, 16
	mov	rcx, r14
	call	rax
	mov	qword ptr [rax - 8], r14
	mov	qword ptr [rax], rbx
	mov	qword ptr [rbp - 32], 0
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_30:                               # %L113
	movabs	rdi, offset ".Ljl_global#1282.jit"
	movabs	rax, offset j_ArgumentError_1281
	call	rax
	mov	rbx, rax
	mov	qword ptr [rbp - 32], rax
	mov	rdi, qword ptr [r14 + 16]
	movabs	r14, 128967350944432
	add	r14, 72139776
	movabs	rax, offset ijl_gc_small_alloc
	mov	esi, 360
	mov	edx, 16
	mov	rcx, r14
	call	rax
	mov	qword ptr [rax - 8], r14
	mov	qword ptr [rax], rbx
	mov	qword ptr [rbp - 32], 0
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.Lfunc_end0:
	.size	julia_norm_diff_1274, .Lfunc_end0-julia_norm_diff_1274
                                        # -- End function
	.type	".L+Core.Float64#1276",@object  # @"+Core.Float64#1276"
	.section	.lrodata,"al",@progbits
	.p2align	3, 0x0
".L+Core.Float64#1276":
	.quad	".L+Core.Float64#1276.jit"
	.size	".L+Core.Float64#1276", 8

.set ".Ljl_global#1282.jit", 128966734970752
	.size	".Ljl_global#1282.jit", 8
.set ".L+Main.Base.DimensionMismatch#1286.jit", 128967350944432
	.size	".L+Main.Base.DimensionMismatch#1286.jit", 8
.set ".L+Core.Float64#1276.jit", 128967417589696
	.size	".L+Core.Float64#1276.jit", 8
.set ".L+Core.ArgumentError#1283.jit", 128967423084208
	.size	".L+Core.ArgumentError#1283.jit", 8
.set ".Ljl_global#1285.jit", 128967479620112
	.size	".Ljl_global#1285.jit", 8
	.section	".note.GNU-stack","",@progbits
