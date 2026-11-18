	.file	"norm_diff"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function julia_norm_diff_1025
.LCPI0_0:
	.quad	0x4000000000000000              # double 2
.LCPI0_1:
	.quad	0x7ff0000000000000              # double +Inf
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0
.LCPI0_2:
	.long	0x7fffffff                      # float NaN
	.section	.ltext,"axl",@progbits
	.globl	julia_norm_diff_1025
	.p2align	4
	.type	julia_norm_diff_1025,@function
julia_norm_diff_1025:                   # @julia_norm_diff_1025
; Function Signature: norm_diff(Array{Float32, 1}, Array{Float32, 1}, Float64)
# %bb.0:                                # %top
	#DEBUG_VALUE: norm_diff:A <- [$rdi+0]
	#DEBUG_VALUE: norm_diff:B <- [$rsi+0]
	#DEBUG_VALUE: norm_diff:p <- $xmm0
	push	rbp
	mov	rbp, rsp
	push	r14
	push	rbx
	sub	rsp, 32
	vxorps	xmm1, xmm1, xmm1
	vmovaps	xmmword ptr [rbp - 48], xmm1
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
	jne	.LBB0_43
# %bb.1:                                # %L19
	movabs	rcx, offset .LCPI0_0
	vucomisd	xmm0, qword ptr [rcx]
	jne	.LBB0_4
	jnp	.LBB0_2
.LBB0_4:                                # %L26
	movabs	rcx, offset .LCPI0_1
	vucomisd	xmm0, qword ptr [rcx]
	jb	.LBB0_42
# %bb.5:                                # %L49
	test	rax, rax
	jle	.LBB0_6
# %bb.7:                                # %iter.check
	mov	rcx, qword ptr [rdi]
	mov	rdx, qword ptr [rsi]
	movabs	rsi, offset .LCPI0_2
	cmp	rax, 4
	jae	.LBB0_9
# %bb.8:
	vxorpd	xmm0, xmm0, xmm0
	mov	r9d, 1
	jmp	.LBB0_37
.LBB0_2:                                # %L24
	movabs	rax, offset j__norm_diff2_1027
	call	rax
	jmp	.LBB0_3
.LBB0_6:
	vxorpd	xmm0, xmm0, xmm0
	jmp	.LBB0_3
.LBB0_9:                                # %vector.main.loop.iter.check
	movabs	rdi, 9223372036854775776
	cmp	rax, 32
	jae	.LBB0_15
# %bb.10:
	vxorpd	xmm0, xmm0, xmm0
	xor	r8d, r8d
	jmp	.LBB0_11
.LBB0_15:                               # %vector.ph
	mov	r8, rax
	and	r8, rdi
	vxorps	xmm1, xmm1, xmm1
	xor	r9d, r9d
	vbroadcastss	ymm3, dword ptr [rsi]
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm2, xmm2, xmm2
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4
.LBB0_16:                               # %vector.body
                                        # =>This Inner Loop Header: Depth=1
	vmovups	ymm5, ymmword ptr [rcx + 4*r9]
	vmovups	ymm6, ymmword ptr [rcx + 4*r9 + 32]
	vmovups	ymm7, ymmword ptr [rcx + 4*r9 + 64]
	vmovups	ymm8, ymmword ptr [rcx + 4*r9 + 96]
	vsubps	ymm5, ymm5, ymmword ptr [rdx + 4*r9]
	vsubps	ymm6, ymm6, ymmword ptr [rdx + 4*r9 + 32]
	vsubps	ymm7, ymm7, ymmword ptr [rdx + 4*r9 + 64]
	vsubps	ymm8, ymm8, ymmword ptr [rdx + 4*r9 + 96]
	vandps	ymm5, ymm5, ymm3
	vblendvps	ymm9, ymm1, ymm5, ymm1
	vandps	ymm6, ymm6, ymm3
	vblendvps	ymm1, ymm5, ymm1, ymm1
	vmaxps	ymm5, ymm1, ymm9
	vcmpunordps	ymm9, ymm1, ymm1
	vblendvps	ymm1, ymm5, ymm1, ymm9
	vblendvps	ymm5, ymm4, ymm6, ymm4
	vandps	ymm7, ymm7, ymm3
	vblendvps	ymm4, ymm6, ymm4, ymm4
	vmaxps	ymm5, ymm4, ymm5
	vcmpunordps	ymm6, ymm4, ymm4
	vblendvps	ymm4, ymm5, ymm4, ymm6
	vblendvps	ymm5, ymm2, ymm7, ymm2
	vandps	ymm6, ymm8, ymm3
	vblendvps	ymm2, ymm7, ymm2, ymm2
	vmaxps	ymm5, ymm2, ymm5
	vcmpunordps	ymm7, ymm2, ymm2
	vblendvps	ymm2, ymm5, ymm2, ymm7
	vblendvps	ymm5, ymm0, ymm6, ymm0
	vblendvps	ymm0, ymm6, ymm0, ymm0
	vmaxps	ymm5, ymm0, ymm5
	vcmpunordps	ymm6, ymm0, ymm0
	vblendvps	ymm0, ymm5, ymm0, ymm6
	add	r9, 32
	cmp	r8, r9
	jne	.LBB0_16
# %bb.17:                               # %middle.block
	vblendvps	ymm3, ymm1, ymm4, ymm1
	vblendvps	ymm1, ymm4, ymm1, ymm1
	vmaxps	ymm3, ymm1, ymm3
	vcmpunordps	ymm4, ymm1, ymm1
	vblendvps	ymm1, ymm3, ymm1, ymm4
	vblendvps	ymm3, ymm1, ymm2, ymm1
	vblendvps	ymm1, ymm2, ymm1, ymm1
	vmaxps	ymm2, ymm1, ymm3
	vcmpunordps	ymm3, ymm1, ymm1
	vblendvps	ymm1, ymm2, ymm1, ymm3
	vblendvps	ymm2, ymm1, ymm0, ymm1
	vblendvps	ymm0, ymm0, ymm1, ymm1
	vmaxps	ymm1, ymm0, ymm2
	vcmpunordps	ymm2, ymm0, ymm0
	vblendvps	ymm0, ymm1, ymm0, ymm2
	vextractf128	xmm1, ymm0, 1
	vblendvps	xmm2, xmm0, xmm1, xmm0
	vblendvps	xmm0, xmm1, xmm0, xmm0
	vmaxps	xmm1, xmm0, xmm2
	vcmpunordps	xmm2, xmm0, xmm0
	vblendvps	xmm0, xmm1, xmm0, xmm2
	vmovshdup	xmm1, xmm0              # xmm1 = xmm0[1,1,3,3]
	vmovd	r9d, xmm0
	test	r9d, r9d
	js	.LBB0_18
# %bb.19:                               # %middle.block
	vmovaps	xmm2, xmm0
	jmp	.LBB0_20
.LBB0_18:
	vmovaps	xmm2, xmm1
	vmovaps	xmm1, xmm0
.LBB0_20:                               # %middle.block
	vmaxss	xmm2, xmm1, xmm2
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm2, xmm2, xmm1, xmm3
	vmovd	r9d, xmm2
	vshufpd	xmm1, xmm0, xmm0, 1             # xmm1 = xmm0[1,0]
	test	r9d, r9d
	js	.LBB0_21
# %bb.22:                               # %middle.block
	vmovaps	xmm3, xmm2
	jmp	.LBB0_23
.LBB0_21:
	vmovapd	xmm3, xmm1
	vmovaps	xmm1, xmm2
.LBB0_23:                               # %middle.block
	vmaxss	xmm2, xmm1, xmm3
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm1, xmm2, xmm1, xmm3
	vmovd	r9d, xmm1
	vshufps	xmm0, xmm0, xmm0, 255           # xmm0 = xmm0[3,3,3,3]
	test	r9d, r9d
	js	.LBB0_24
# %bb.25:                               # %middle.block
	vmovaps	xmm2, xmm1
	jmp	.LBB0_26
.LBB0_24:
	vmovaps	xmm2, xmm0
	vmovaps	xmm0, xmm1
.LBB0_26:                               # %middle.block
	vmaxss	xmm1, xmm0, xmm2
	vcmpunordss	xmm2, xmm0, xmm0
	vblendvps	xmm0, xmm1, xmm0, xmm2
	cmp	rax, r8
	je	.LBB0_3
# %bb.27:                               # %vec.epilog.iter.check
	test	al, 28
	je	.LBB0_28
.LBB0_11:                               # %vec.epilog.ph
	add	rdi, 28
	and	rdi, rax
	mov	r9, rdi
	or	r9, 1
	vbroadcastss	xmm0, xmm0
	vbroadcastss	xmm1, dword ptr [rsi]
	.p2align	4
.LBB0_12:                               # %vec.epilog.vector.body
                                        # =>This Inner Loop Header: Depth=1
	vmovups	xmm2, xmmword ptr [rcx + 4*r8]
	vsubps	xmm2, xmm2, xmmword ptr [rdx + 4*r8]
	vandps	xmm2, xmm2, xmm1
	vblendvps	xmm3, xmm0, xmm2, xmm0
	vblendvps	xmm0, xmm2, xmm0, xmm0
	vmaxps	xmm2, xmm0, xmm3
	vcmpunordps	xmm3, xmm0, xmm0
	vblendvps	xmm0, xmm2, xmm0, xmm3
	add	r8, 4
	cmp	rdi, r8
	jne	.LBB0_12
# %bb.13:                               # %vec.epilog.middle.block
	vmovshdup	xmm1, xmm0              # xmm1 = xmm0[1,1,3,3]
	vmovd	r8d, xmm0
	test	r8d, r8d
	js	.LBB0_14
# %bb.29:                               # %vec.epilog.middle.block
	vmovaps	xmm2, xmm0
	jmp	.LBB0_30
.LBB0_14:
	vmovaps	xmm2, xmm1
	vmovaps	xmm1, xmm0
.LBB0_30:                               # %vec.epilog.middle.block
	vmaxss	xmm2, xmm1, xmm2
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm2, xmm2, xmm1, xmm3
	vmovd	r8d, xmm2
	vshufpd	xmm1, xmm0, xmm0, 1             # xmm1 = xmm0[1,0]
	test	r8d, r8d
	js	.LBB0_31
# %bb.32:                               # %vec.epilog.middle.block
	vmovaps	xmm3, xmm2
	jmp	.LBB0_33
.LBB0_31:
	vmovapd	xmm3, xmm1
	vmovaps	xmm1, xmm2
.LBB0_33:                               # %vec.epilog.middle.block
	vmaxss	xmm2, xmm1, xmm3
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm1, xmm2, xmm1, xmm3
	vmovd	r8d, xmm1
	vshufps	xmm0, xmm0, xmm0, 255           # xmm0 = xmm0[3,3,3,3]
	test	r8d, r8d
	js	.LBB0_34
# %bb.35:                               # %vec.epilog.middle.block
	vmovaps	xmm2, xmm1
	jmp	.LBB0_36
.LBB0_34:
	vmovaps	xmm2, xmm0
	vmovaps	xmm0, xmm1
.LBB0_36:                               # %vec.epilog.middle.block
	vmaxss	xmm1, xmm0, xmm2
	vcmpunordss	xmm2, xmm0, xmm0
	vblendvps	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rdi
	jne	.LBB0_37
.LBB0_3:                                # %common.ret
	mov	rax, qword ptr [rbp - 40]
	mov	qword ptr [r14], rax
	add	rsp, 32
	pop	rbx
	pop	r14
	pop	rbp
	vzeroupper
	ret
.LBB0_28:
	or	r8, 1
	mov	r9, r8
.LBB0_37:                               # %L58.preheader
	dec	r9
	vbroadcastss	xmm1, dword ptr [rsi]
	jmp	.LBB0_38
	.p2align	4
.LBB0_40:                               # %L58
                                        #   in Loop: Header=BB0_38 Depth=1
	vmovaps	xmm3, xmm0
.LBB0_41:                               # %L58
                                        #   in Loop: Header=BB0_38 Depth=1
	vmaxss	xmm0, xmm2, xmm3
	vcmpunordss	xmm3, xmm2, xmm2
	vblendvps	xmm0, xmm0, xmm2, xmm3
	inc	r9
	cmp	rax, r9
	je	.LBB0_3
.LBB0_38:                               # %L58
                                        # =>This Inner Loop Header: Depth=1
	vmovss	xmm2, dword ptr [rcx + 4*r9]    # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm2, xmm2, dword ptr [rdx + 4*r9]
	vandps	xmm2, xmm2, xmm1
	vmovd	esi, xmm0
	test	esi, esi
	jns	.LBB0_40
# %bb.39:                               #   in Loop: Header=BB0_38 Depth=1
	vmovaps	xmm3, xmm2
	vmovaps	xmm2, xmm0
	jmp	.LBB0_41
.LBB0_43:                               # %L116
	movabs	rdi, offset ".Ljl_global#1035.jit"
	movabs	rax, offset j_DimensionMismatch_1034
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
.LBB0_42:                               # %L113
	movabs	rdi, offset ".Ljl_global#1032.jit"
	movabs	rax, offset j_ArgumentError_1031
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
	.size	julia_norm_diff_1025, .Lfunc_end0-julia_norm_diff_1025
                                        # -- End function
.set ".Ljl_global#1032.jit", 128966734970752
	.size	".Ljl_global#1032.jit", 8
.set ".L+Main.Base.DimensionMismatch#1036.jit", 128967350944432
	.size	".L+Main.Base.DimensionMismatch#1036.jit", 8
.set ".L+Core.ArgumentError#1033.jit", 128967423084208
	.size	".L+Core.ArgumentError#1033.jit", 8
.set ".Ljl_global#1035.jit", 128967479620112
	.size	".Ljl_global#1035.jit", 8
	.section	".note.GNU-stack","",@progbits
