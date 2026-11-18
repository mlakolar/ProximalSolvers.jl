	.text
	.file	"norm_diff"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia_norm_diff_717
.LCPI0_0:
	.quad	0x4000000000000000              # double 2
.LCPI0_1:
	.quad	0x7ff0000000000000              # double +Inf
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4
.LCPI0_2:
	.quad	0x7fffffffffffffff              # double NaN
	.quad	0x7fffffffffffffff              # double NaN
	.text
	.globl	julia_norm_diff_717
	.p2align	4, 0x90
	.type	julia_norm_diff_717,@function
julia_norm_diff_717:                    # @julia_norm_diff_717
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r14
	push	rbx
	sub	rsp, 48
	vxorpd	xmm1, xmm1, xmm1
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	lea	rcx, [rbp - 48]
	vmovapd	xmmword ptr [rbp - 48], xmm1
	mov	qword ptr [rbp - 32], 0
	mov	rbx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 48], 4
	mov	rax, qword ptr [rbx]
	mov	qword ptr [rbp - 40], rax
	mov	qword ptr [rbx], rcx
	mov	rax, qword ptr [rdi + 8]
	cmp	rax, qword ptr [rsi + 8]
	jne	.LBB0_12
# %bb.1:                                # %L13
	movabs	rcx, offset .LCPI0_0
	vucomisd	xmm0, qword ptr [rcx]
	jne	.LBB0_4
	jnp	.LBB0_2
.LBB0_4:                                # %L20
	movabs	rcx, offset .LCPI0_1
	vucomisd	xmm0, qword ptr [rcx]
	jb	.LBB0_11
# %bb.5:                                # %L44
	test	rax, rax
	je	.LBB0_6
# %bb.7:                                # %L53.preheader
	movabs	r8, offset .LCPI0_2
	mov	rdx, qword ptr [rsi]
	mov	rcx, qword ptr [rdi]
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	vmovapd	xmm1, xmmword ptr [r8]
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_10:                               # %L53
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpordsd	xmm0, xmm0, xmm2
	add	rsi, 1
	cmp	rax, rsi
	vblendvpd	xmm0, xmm4, xmm3, xmm0
	je	.LBB0_3
.LBB0_8:                                # %L53
                                        # =>This Inner Loop Header: Depth=1
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vsubsd	xmm2, xmm2, qword ptr [rdx + 8*rsi]
	vandpd	xmm3, xmm2, xmm1
	vsubsd	xmm4, xmm0, xmm3
	vmovq	rdi, xmm4
	test	rdi, rdi
	js	.LBB0_10
# %bb.9:                                # %L53
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovapd	xmm3, xmm0
	jmp	.LBB0_10
.LBB0_2:                                # %L18
	movabs	rax, offset j__norm_diff2_719
	call	rax
	jmp	.LBB0_3
.LBB0_6:
	vxorpd	xmm0, xmm0, xmm0
.LBB0_3:                                # %common.ret
	mov	rax, qword ptr [rbp - 40]
	mov	qword ptr [rbx], rax
	add	rsp, 48
	pop	rbx
	pop	r14
	pop	rbp
	ret
.LBB0_12:                               # %L84
	movabs	rax, offset j_DimensionMismatch_720
	movabs	rdi, 124168008058432
	call	rax
	mov	qword ptr [rbp - 32], rax
	mov	r14, rax
	movabs	rax, offset ijl_gc_pool_alloc
	mov	esi, 752
	mov	edx, 16
	mov	rdi, qword ptr [rbx + 16]
	call	rax
	movabs	rcx, 124167910077920
	mov	rdi, rax
	mov	qword ptr [rax - 8], rcx
	movabs	rcx, offset ijl_throw
	mov	qword ptr [rax], r14
	call	rcx
.LBB0_11:                               # %L81
	movabs	rax, 124166376122368
	movabs	rdi, 124167938848416
	lea	rsi, [rbp - 56]
	mov	edx, 1
	mov	qword ptr [rbp - 56], rax
	movabs	rax, offset ijl_apply_generic
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.Lfunc_end0:
	.size	julia_norm_diff_717, .Lfunc_end0-julia_norm_diff_717
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
