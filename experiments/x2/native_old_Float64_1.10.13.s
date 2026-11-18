	.text
	.file	"_maxabs_diff"
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4                               # -- Begin function julia__maxabs_diff_714
.LCPI0_0:
	.quad	0x7fffffffffffffff              # double NaN
	.quad	0x7fffffffffffffff              # double NaN
	.text
	.globl	julia__maxabs_diff_714
	.p2align	4, 0x90
	.type	julia__maxabs_diff_714,@function
julia__maxabs_diff_714:                 # @julia__maxabs_diff_714
# %bb.0:                                # %top
	push	rbp
	mov	rax, qword ptr [rdi + 8]
	mov	rbp, rsp
	test	rax, rax
	je	.LBB0_1
# %bb.2:                                # %L13.lr.ph
	movabs	r8, offset .LCPI0_0
	mov	rdx, qword ptr [rsi]
	mov	rcx, qword ptr [rdi]
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	vmovapd	xmm1, xmmword ptr [r8]
	jmp	.LBB0_3
	.p2align	4, 0x90
.LBB0_5:                                # %L13
                                        #   in Loop: Header=BB0_3 Depth=1
	vcmpordsd	xmm0, xmm0, xmm2
	add	rsi, 1
	cmp	rax, rsi
	vblendvpd	xmm0, xmm4, xmm3, xmm0
	je	.LBB0_6
.LBB0_3:                                # %L13
                                        # =>This Inner Loop Header: Depth=1
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vsubsd	xmm2, xmm2, qword ptr [rdx + 8*rsi]
	vandpd	xmm3, xmm2, xmm1
	vsubsd	xmm4, xmm0, xmm3
	vmovq	rdi, xmm4
	test	rdi, rdi
	js	.LBB0_5
# %bb.4:                                # %L13
                                        #   in Loop: Header=BB0_3 Depth=1
	vmovapd	xmm3, xmm0
	jmp	.LBB0_5
.LBB0_6:                                # %L40
	pop	rbp
	ret
.LBB0_1:
	vxorps	xmm0, xmm0, xmm0
	pop	rbp
	ret
.Lfunc_end0:
	.size	julia__maxabs_diff_714, .Lfunc_end0-julia__maxabs_diff_714
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
