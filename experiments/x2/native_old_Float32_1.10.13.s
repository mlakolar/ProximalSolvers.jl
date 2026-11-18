	.text
	.file	"_maxabs_diff"
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2                               # -- Begin function julia__maxabs_diff_620
.LCPI0_0:
	.long	0x7fffffff                      # float NaN
	.text
	.globl	julia__maxabs_diff_620
	.p2align	4, 0x90
	.type	julia__maxabs_diff_620,@function
julia__maxabs_diff_620:                 # @julia__maxabs_diff_620
# %bb.0:                                # %top
	push	rbp
	mov	rax, qword ptr [rdi + 8]
	mov	rbp, rsp
	test	rax, rax
	je	.LBB0_1
# %bb.2:                                # %L13.lr.ph
	movabs	rcx, offset .LCPI0_0
	mov	rdx, qword ptr [rsi]
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	vbroadcastss	xmm1, dword ptr [rcx]
	mov	rcx, qword ptr [rdi]
	jmp	.LBB0_3
	.p2align	4, 0x90
.LBB0_5:                                # %L13
                                        #   in Loop: Header=BB0_3 Depth=1
	vcmpordss	xmm0, xmm0, xmm2
	add	rsi, 1
	cmp	rax, rsi
	vblendvps	xmm0, xmm4, xmm3, xmm0
	je	.LBB0_6
.LBB0_3:                                # %L13
                                        # =>This Inner Loop Header: Depth=1
	vmovss	xmm2, dword ptr [rcx + 4*rsi]   # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm2, xmm2, dword ptr [rdx + 4*rsi]
	vandps	xmm3, xmm2, xmm1
	vsubss	xmm4, xmm0, xmm3
	vmovd	edi, xmm4
	test	edi, edi
	js	.LBB0_5
# %bb.4:                                # %L13
                                        #   in Loop: Header=BB0_3 Depth=1
	vmovaps	xmm3, xmm0
	jmp	.LBB0_5
.LBB0_6:                                # %L41
	pop	rbp
	ret
.LBB0_1:
	vxorps	xmm0, xmm0, xmm0
	pop	rbp
	ret
.Lfunc_end0:
	.size	julia__maxabs_diff_620, .Lfunc_end0-julia__maxabs_diff_620
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
