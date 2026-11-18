	.file	"_maxabs_diff"
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0                          # -- Begin function julia__maxabs_diff_1006
.LCPI0_0:
	.long	0x7fffffff                      # float NaN
	.section	.ltext,"axl",@progbits
	.globl	julia__maxabs_diff_1006
	.p2align	4
	.type	julia__maxabs_diff_1006,@function
julia__maxabs_diff_1006:                # @julia__maxabs_diff_1006
; Function Signature: _maxabs_diff(Array{Float32, 1}, Array{Float32, 1})
# %bb.0:                                # %top
	#DEBUG_VALUE: _maxabs_diff:x <- [$rdi+0]
	#DEBUG_VALUE: _maxabs_diff:y <- [$rsi+0]
	mov	rax, qword ptr [rdi + 16]
	test	rax, rax
	jle	.LBB0_1
# %bb.3:                                # %iter.check
	push	rbp
	mov	rbp, rsp
	mov	rcx, qword ptr [rdi]
	mov	rdx, qword ptr [rsi]
	movabs	rdi, offset .LCPI0_0
	cmp	rax, 4
	jae	.LBB0_5
# %bb.4:
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_32
.LBB0_1:
	vxorps	xmm0, xmm0, xmm0
	ret
.LBB0_5:                                # %vector.main.loop.iter.check
	movabs	r8, 9223372036854775776
	cmp	rax, 32
	jae	.LBB0_7
# %bb.6:
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_20
.LBB0_7:                                # %vector.ph
	mov	rsi, rax
	and	rsi, r8
	vxorps	xmm1, xmm1, xmm1
	xor	r9d, r9d
	vbroadcastss	ymm3, dword ptr [rdi]
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm0, xmm0, xmm0
	.p2align	4
.LBB0_8:                                # %vector.body
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
	cmp	rsi, r9
	jne	.LBB0_8
# %bb.9:                                # %middle.block
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
	js	.LBB0_10
# %bb.11:                               # %middle.block
	vmovaps	xmm2, xmm0
	jmp	.LBB0_12
.LBB0_10:
	vmovaps	xmm2, xmm1
	vmovaps	xmm1, xmm0
.LBB0_12:                               # %middle.block
	vmaxss	xmm2, xmm1, xmm2
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm2, xmm2, xmm1, xmm3
	vmovd	r9d, xmm2
	vshufpd	xmm1, xmm0, xmm0, 1             # xmm1 = xmm0[1,0]
	test	r9d, r9d
	js	.LBB0_13
# %bb.14:                               # %middle.block
	vmovaps	xmm3, xmm2
	jmp	.LBB0_15
.LBB0_13:
	vmovapd	xmm3, xmm1
	vmovaps	xmm1, xmm2
.LBB0_15:                               # %middle.block
	vmaxss	xmm2, xmm1, xmm3
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm1, xmm2, xmm1, xmm3
	vmovd	r9d, xmm1
	vshufps	xmm0, xmm0, xmm0, 255           # xmm0 = xmm0[3,3,3,3]
	test	r9d, r9d
	js	.LBB0_16
# %bb.17:                               # %middle.block
	vmovaps	xmm2, xmm1
	jmp	.LBB0_18
.LBB0_16:
	vmovaps	xmm2, xmm0
	vmovaps	xmm0, xmm1
.LBB0_18:                               # %middle.block
	vmaxss	xmm1, xmm0, xmm2
	vcmpunordss	xmm2, xmm0, xmm0
	vblendvps	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rsi
	je	.LBB0_37
# %bb.19:                               # %vec.epilog.iter.check
	test	al, 28
	je	.LBB0_32
.LBB0_20:                               # %vec.epilog.ph
	mov	r9, rsi
	add	r8, 28
	mov	rsi, r8
	and	rsi, rax
	vbroadcastss	xmm0, xmm0
	vbroadcastss	xmm1, dword ptr [rdi]
	.p2align	4
.LBB0_21:                               # %vec.epilog.vector.body
                                        # =>This Inner Loop Header: Depth=1
	vmovups	xmm2, xmmword ptr [rcx + 4*r9]
	vsubps	xmm2, xmm2, xmmword ptr [rdx + 4*r9]
	vandps	xmm2, xmm2, xmm1
	vblendvps	xmm3, xmm0, xmm2, xmm0
	vblendvps	xmm0, xmm2, xmm0, xmm0
	vmaxps	xmm2, xmm0, xmm3
	vcmpunordps	xmm3, xmm0, xmm0
	vblendvps	xmm0, xmm2, xmm0, xmm3
	add	r9, 4
	cmp	rsi, r9
	jne	.LBB0_21
# %bb.22:                               # %vec.epilog.middle.block
	vmovshdup	xmm1, xmm0              # xmm1 = xmm0[1,1,3,3]
	vmovd	r8d, xmm0
	test	r8d, r8d
	js	.LBB0_23
# %bb.24:                               # %vec.epilog.middle.block
	vmovaps	xmm2, xmm0
	jmp	.LBB0_25
.LBB0_23:
	vmovaps	xmm2, xmm1
	vmovaps	xmm1, xmm0
.LBB0_25:                               # %vec.epilog.middle.block
	vmaxss	xmm2, xmm1, xmm2
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm2, xmm2, xmm1, xmm3
	vmovd	r8d, xmm2
	vshufpd	xmm1, xmm0, xmm0, 1             # xmm1 = xmm0[1,0]
	test	r8d, r8d
	js	.LBB0_26
# %bb.27:                               # %vec.epilog.middle.block
	vmovaps	xmm3, xmm2
	jmp	.LBB0_28
.LBB0_26:
	vmovapd	xmm3, xmm1
	vmovaps	xmm1, xmm2
.LBB0_28:                               # %vec.epilog.middle.block
	vmaxss	xmm2, xmm1, xmm3
	vcmpunordss	xmm3, xmm1, xmm1
	vblendvps	xmm1, xmm2, xmm1, xmm3
	vmovd	r8d, xmm1
	vshufps	xmm0, xmm0, xmm0, 255           # xmm0 = xmm0[3,3,3,3]
	test	r8d, r8d
	js	.LBB0_29
# %bb.30:                               # %vec.epilog.middle.block
	vmovaps	xmm2, xmm1
	jmp	.LBB0_31
.LBB0_29:
	vmovaps	xmm2, xmm0
	vmovaps	xmm0, xmm1
.LBB0_31:                               # %vec.epilog.middle.block
	vmaxss	xmm1, xmm0, xmm2
	vcmpunordss	xmm2, xmm0, xmm0
	vblendvps	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rsi
	jne	.LBB0_32
.LBB0_37:
	pop	rbp
	vzeroupper
	ret
.LBB0_32:                               # %L12.preheader
	vbroadcastss	xmm1, dword ptr [rdi]
	jmp	.LBB0_33
	.p2align	4
.LBB0_35:                               # %L12
                                        #   in Loop: Header=BB0_33 Depth=1
	vmovaps	xmm3, xmm0
.LBB0_36:                               # %L12
                                        #   in Loop: Header=BB0_33 Depth=1
	inc	rsi
	vmaxss	xmm0, xmm2, xmm3
	vcmpunordss	xmm3, xmm2, xmm2
	vblendvps	xmm0, xmm0, xmm2, xmm3
	cmp	rax, rsi
	je	.LBB0_37
.LBB0_33:                               # %L12
                                        # =>This Inner Loop Header: Depth=1
	vmovss	xmm2, dword ptr [rcx + 4*rsi]   # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm2, xmm2, dword ptr [rdx + 4*rsi]
	vandps	xmm2, xmm2, xmm1
	vmovd	edi, xmm0
	test	edi, edi
	jns	.LBB0_35
# %bb.34:                               #   in Loop: Header=BB0_33 Depth=1
	vmovaps	xmm3, xmm2
	vmovaps	xmm2, xmm0
	jmp	.LBB0_36
.Lfunc_end0:
	.size	julia__maxabs_diff_1006, .Lfunc_end0-julia__maxabs_diff_1006
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
