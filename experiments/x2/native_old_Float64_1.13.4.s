	.file	"_maxabs_diff"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function julia__maxabs_diff_1257
.LCPI0_0:
	.quad	0x7fffffffffffffff              # double NaN
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI0_1:
	.quad	0x7fffffffffffffff              # double NaN
	.quad	0x7fffffffffffffff              # double NaN
	.section	.ltext,"axl",@progbits
	.globl	julia__maxabs_diff_1257
	.p2align	4
	.type	julia__maxabs_diff_1257,@function
julia__maxabs_diff_1257:                # @julia__maxabs_diff_1257
; Function Signature: _maxabs_diff(Array{Float64, 1}, Array{Float64, 1})
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
	cmp	rax, 4
	jae	.LBB0_5
# %bb.4:
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_20
.LBB0_1:
	vxorps	xmm0, xmm0, xmm0
	ret
.LBB0_5:                                # %vector.main.loop.iter.check
	movabs	r8, 9223372036854775792
	movabs	rdi, offset .LCPI0_0
	cmp	rax, 16
	jae	.LBB0_7
# %bb.6:
	vxorpd	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_14
.LBB0_7:                                # %vector.ph
	mov	rsi, rax
	and	rsi, r8
	vxorpd	xmm1, xmm1, xmm1
	xor	r9d, r9d
	vbroadcastsd	ymm3, qword ptr [rdi]
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm0, xmm0, xmm0
	.p2align	4
.LBB0_8:                                # %vector.body
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
	cmp	rsi, r9
	jne	.LBB0_8
# %bb.9:                                # %middle.block
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
	js	.LBB0_10
# %bb.11:                               # %middle.block
	vmovapd	xmm2, xmm1
	jmp	.LBB0_12
.LBB0_10:
	vmovapd	xmm2, xmm0
	vmovapd	xmm0, xmm1
.LBB0_12:                               # %middle.block
	vmaxsd	xmm1, xmm0, xmm2
	vcmpunordsd	xmm2, xmm0, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rsi
	je	.LBB0_25
# %bb.13:                               # %vec.epilog.iter.check
	test	al, 12
	je	.LBB0_20
.LBB0_14:                               # %vec.epilog.ph
	mov	r9, rsi
	add	r8, 12
	mov	rsi, r8
	and	rsi, rax
	vbroadcastsd	ymm0, xmm0
	vbroadcastsd	ymm1, qword ptr [rdi]
	.p2align	4
.LBB0_15:                               # %vec.epilog.vector.body
                                        # =>This Inner Loop Header: Depth=1
	vmovupd	ymm2, ymmword ptr [rcx + 8*r9]
	vsubpd	ymm2, ymm2, ymmword ptr [rdx + 8*r9]
	vandpd	ymm2, ymm2, ymm1
	vblendvpd	ymm3, ymm0, ymm2, ymm0
	vblendvpd	ymm0, ymm2, ymm0, ymm0
	vmaxpd	ymm2, ymm0, ymm3
	vcmpunordpd	ymm3, ymm0, ymm0
	vblendvpd	ymm0, ymm2, ymm0, ymm3
	add	r9, 4
	cmp	rsi, r9
	jne	.LBB0_15
# %bb.16:                               # %vec.epilog.middle.block
	vextractf128	xmm1, ymm0, 1
	vblendvpd	xmm2, xmm0, xmm1, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm0
	vmaxpd	xmm1, xmm0, xmm2
	vcmpunordpd	xmm2, xmm0, xmm0
	vblendvpd	xmm1, xmm1, xmm0, xmm2
	vshufpd	xmm0, xmm1, xmm1, 1             # xmm0 = xmm1[1,0]
	vmovq	rdi, xmm1
	test	rdi, rdi
	js	.LBB0_17
# %bb.18:                               # %vec.epilog.middle.block
	vmovapd	xmm2, xmm1
	jmp	.LBB0_19
.LBB0_17:
	vmovapd	xmm2, xmm0
	vmovapd	xmm0, xmm1
.LBB0_19:                               # %vec.epilog.middle.block
	vmaxsd	xmm1, xmm0, xmm2
	vcmpunordsd	xmm2, xmm0, xmm0
	vblendvpd	xmm0, xmm1, xmm0, xmm2
	cmp	rax, rsi
	jne	.LBB0_20
.LBB0_25:
	pop	rbp
	vzeroupper
	ret
.LBB0_20:                               # %L12.preheader
	movabs	rdi, offset .LCPI0_1
	vmovapd	xmm1, xmmword ptr [rdi]
	jmp	.LBB0_21
	.p2align	4
.LBB0_23:                               # %L12
                                        #   in Loop: Header=BB0_21 Depth=1
	vmovapd	xmm3, xmm0
.LBB0_24:                               # %L12
                                        #   in Loop: Header=BB0_21 Depth=1
	inc	rsi
	vmaxsd	xmm0, xmm2, xmm3
	vcmpunordsd	xmm3, xmm2, xmm2
	vblendvpd	xmm0, xmm0, xmm2, xmm3
	cmp	rax, rsi
	je	.LBB0_25
.LBB0_21:                               # %L12
                                        # =>This Inner Loop Header: Depth=1
	vmovsd	xmm2, qword ptr [rcx + 8*rsi]   # xmm2 = mem[0],zero
	vsubsd	xmm2, xmm2, qword ptr [rdx + 8*rsi]
	vandpd	xmm2, xmm2, xmm1
	vmovq	rdi, xmm0
	test	rdi, rdi
	jns	.LBB0_23
# %bb.22:                               #   in Loop: Header=BB0_21 Depth=1
	vmovapd	xmm3, xmm2
	vmovapd	xmm2, xmm0
	jmp	.LBB0_24
.Lfunc_end0:
	.size	julia__maxabs_diff_1257, .Lfunc_end0-julia__maxabs_diff_1257
                                        # -- End function
	.type	".L+Core.Float64#1259",@object  # @"+Core.Float64#1259"
	.section	.lrodata,"al",@progbits
	.p2align	3, 0x0
".L+Core.Float64#1259":
	.quad	".L+Core.Float64#1259.jit"
	.size	".L+Core.Float64#1259", 8

.set ".L+Core.Float64#1259.jit", 128967417589696
	.size	".L+Core.Float64#1259.jit", 8
	.section	".note.GNU-stack","",@progbits
