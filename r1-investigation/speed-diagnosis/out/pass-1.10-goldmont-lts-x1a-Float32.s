	.text
	.file	"pass"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia_pass_2112
.LCPI0_0:
	.long	0x00000000                      # float 0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2
.LCPI0_1:
	.long	0x80000000                      # float -0
.LCPI0_2:
	.long	0x0c000000                      # float 9.86076131E-32
.LCPI0_3:
	.long	0x3d800000                      # float 0.0625
.LCPI0_4:
	.long	0x7f7fffff                      # float 3.40282347E+38
.LCPI0_5:
	.long	0x00800000                      # float 1.17549435E-38
.LCPI0_6:
	.long	0x3f800000                      # float 1
	.text
	.globl	julia_pass_2112
	.p2align	4, 0x90
	.type	julia_pass_2112,@function
julia_pass_2112:                        # @julia_pass_2112
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	and	rsp, -32
	sub	rsp, 352
	mov	rbx, rsp
	vxorps	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	vmovaps	ymmword ptr [rbx + 64], ymm0
	mov	qword ptr [rbx + 104], 0
	mov	qword ptr [rbx + 96], 0
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 64], 16
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbx + 72], rax
	lea	rax, [rbx + 64]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbx + 136], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	r11, rsi
	mov	rsi, qword ptr [rsi + 8]
	mov	qword ptr [rbx + 128], rcx      # 8-byte Spill
	test	rsi, rsi
	je	.LBB0_3
# %bb.4:                                # %L17.preheader495
	movabs	rax, offset .LCPI0_1
	mov	rdx, qword ptr [rdi]
	vxorps	xmm12, xmm12, xmm12
	mov	ecx, 1
	vxorps	xmm11, xmm11, xmm11
                                        # implicit-def: $r15
	mov	qword ptr [rbx + 40], r11       # 8-byte Spill
	mov	qword ptr [rbx + 24], rdi       # 8-byte Spill
	vbroadcastss	ymm0, dword ptr [rax]
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm1, ymmword ptr [rax]
                                        # implicit-def: $rax
	mov	qword ptr [rbx + 48], rdx       # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 288], ymm0   # 32-byte Spill
	vmovaps	ymmword ptr [rbx + 256], ymm1   # 32-byte Spill
	test	rsi, rsi
	je	.LBB0_70
	.p2align	4, 0x90
.LBB0_7:                                # %L31.preheader
	mov	r12d, 1
	xor	r14d, r14d
	mov	qword ptr [rbx + 144], rcx      # 8-byte Spill
	mov	qword ptr [rbx + 152], rsi      # 8-byte Spill
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_67:                               # %L358
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	qword ptr [rbx + 88], rdi
	mov	qword ptr [rbx + 160], rdi
	mov	rdi, qword ptr [rbx + 24]       # 8-byte Reload
	lea	rsi, [rbx + 160]
	lea	rcx, [rbx + 32]
	mov	r8, r12
	mov	qword ptr [rbx + 168], r15
	mov	qword ptr [rbx + 176], r12
	mov	qword ptr [rbx + 184], r9
	mov	qword ptr [rbx + 192], 1
	vmovss	dword ptr [rbx + 20], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 104], rax
	movabs	rax, offset j__sqrt_cold_2118
	mov	qword ptr [rbx + 96], rdx
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 20]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 40]       # 8-byte Reload
	vxorps	xmm12, xmm12, xmm12
	vmovaps	xmm3, xmm0
.LBB0_68:                               # %L362
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, qword ptr [rbx + 152]      # 8-byte Reload
	vaddss	xmm11, xmm11, xmm3
	mov	rdx, qword ptr [rbx + 48]       # 8-byte Reload
	add	r14, 4
	cmp	r12, rsi
	lea	r12, [r12 + 1]
	je	.LBB0_69
.LBB0_8:                                # %L31
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_18 Depth 2
                                        #     Child Loop BB0_21 Depth 2
                                        #     Child Loop BB0_27 Depth 2
                                        #     Child Loop BB0_30 Depth 2
                                        #     Child Loop BB0_47 Depth 2
                                        #     Child Loop BB0_50 Depth 2
	mov	rdi, qword ptr [rdx + 32]
	lea	r9, [r12 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rcx, qword ptr [rdx]
	vmovss	xmm1, dword ptr [rax + 4*r12 - 4] # xmm1 = mem[0],zero,zero,zero
	mov	rax, qword ptr [rdx + 24]
	vucomiss	xmm1, xmm1
	mov	r10, qword ptr [rax + 8]
	jp	.LBB0_13
# %bb.22:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r13, qword ptr [rbx + 24]       # 8-byte Reload
	test	r10, r10
	je	.LBB0_23
# %bb.24:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rdx, qword ptr [rcx]
	mov	r8, qword ptr [rcx + 24]
	mov	rsi, qword ptr [rax]
	cmp	r10, 16
	jae	.LBB0_26
# %bb.25:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm4, xmm4, xmm4
	xor	edi, edi
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_23:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_26:                               # %vector.ph403
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rdi, r10
	movabs	rax, 9223372036854775792
	vmovaps	ymm3, ymmword ptr [rbx + 256]   # 32-byte Reload
	vmovaps	ymm4, ymmword ptr [rbx + 288]   # 32-byte Reload
	xor	ecx, ecx
	and	rdi, rax
	mov	rax, r8
	imul	rax, r14
	vmovaps	ymm0, ymm3
	vmovaps	ymm2, ymm4
	add	rax, rdx
	add	rax, 32
	.p2align	4, 0x90
.LBB0_27:                               # %vector.body408
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm5, ymmword ptr [rsi + 4*rcx]
	vmovups	ymm6, ymmword ptr [rsi + 4*rcx + 32]
	vfmadd231ps	ymm0, ymm5, ymmword ptr [rax + 4*rcx - 32] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rax + 4*rcx] # ymm2 = (ymm6 * mem) + ymm2
	add	rcx, 16
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	cmp	rdi, rcx
	jne	.LBB0_27
# %bb.28:                               # %middle.block400
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddps	ymm3, ymm4, ymm3
	vaddps	ymm0, ymm2, ymm0
	cmp	r10, rdi
	vextractf128	xmm2, ymm3, 1
	vaddps	xmm2, xmm3, xmm2
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddps	xmm2, xmm2, xmm3
	vaddps	xmm0, xmm0, xmm4
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vmovshdup	xmm4, xmm0              # xmm4 = xmm0[1,1,3,3]
	vaddss	xmm2, xmm2, xmm3
	vaddss	xmm4, xmm0, xmm4
	je	.LBB0_31
.LBB0_29:                               # %scalar.ph401
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, r14
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_30:                               # %L96
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rsi + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm4, xmm0, dword ptr [rdx + 4*rdi] # xmm4 = (xmm0 * mem) + xmm4
	add	rdi, 1
	vfmadd231ss	xmm2, xmm0, xmm0        # xmm2 = (xmm0 * xmm0) + xmm2
	cmp	r10, rdi
	jne	.LBB0_30
.LBB0_31:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=1
	cmp	r9, qword ptr [r11 + 8]
	jae	.LBB0_32
# %bb.75:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [r13]
	mov	rdi, qword ptr [rax]
	cmp	r9, qword ptr [rdi + 32]
	mov	r15, qword ptr [rdi + 24]
	jae	.LBB0_76
# %bb.35:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubss	xmm0, xmm1, xmm1
	mov	rcx, qword ptr [r11]
	imul	r9, r15
	mov	rdx, qword ptr [rax + 24]
	mov	r13d, dword ptr [r13 + 8]
	vucomiss	xmm0, xmm0
	vmovss	xmm0, dword ptr [rcx + 4*r12 - 4] # xmm0 = mem[0],zero,zero,zero
	mov	dword ptr [rbx + 32], r13d
	jp	.LBB0_67
# %bb.36:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r10, qword ptr [rdx + 8]
	movabs	rax, offset .LCPI0_2
	vcvtsi2ss	xmm3, xmm14, r10
	vmulss	xmm3, xmm3, dword ptr [rax]
	vucomiss	xmm1, xmm3
	jb	.LBB0_67
# %bb.37:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubss	xmm5, xmm2, xmm2
	vucomiss	xmm5, xmm5
	jp	.LBB0_67
# %bb.38:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomiss	xmm2, xmm3
	jb	.LBB0_67
# %bb.39:                               # %L179
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomiss	xmm12, xmm1
	ja	.LBB0_77
# %bb.40:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=1
	vsqrtss	xmm6, xmm1, xmm1
	vmovd	xmm8, r13d
	vxorps	xmm3, xmm3, xmm3
	vucomiss	xmm8, xmm6
	jae	.LBB0_68
# %bb.41:                               # %L189
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivss	xmm7, xmm4, xmm1
	movabs	rax, offset .LCPI0_3
	vmulss	xmm3, xmm4, xmm7
	vmulss	xmm4, xmm2, dword ptr [rax]
	vsubss	xmm3, xmm2, xmm3
	vucomiss	xmm4, xmm3
	jbe	.LBB0_51
# %bb.42:                               # %L196
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10, r10
	je	.LBB0_43
# %bb.44:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rdx]
	mov	r8, qword ptr [rdi]
	cmp	r10, 16
	jae	.LBB0_46
# %bb.45:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm3, xmm3, xmm3
	xor	ecx, ecx
	jmp	.LBB0_49
.LBB0_43:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_52
.LBB0_46:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r10
	movabs	rax, 9223372036854775792
	movabs	rsi, offset .LCPI0_0
	vbroadcastss	ymm3, xmm7
	and	rcx, rax
	movabs	rax, offset .LCPI0_1
	vmovaps	ymm4, ymmword ptr [rsi]
	xor	esi, esi
	vbroadcastss	ymm2, dword ptr [rax]
	mov	rax, r15
	imul	rax, r14
	add	rax, r8
	add	rax, 32
	.p2align	4, 0x90
.LBB0_47:                               # %vector.body
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm5, ymm3, ymmword ptr [rax + 4*rsi - 32]
	vmulps	ymm9, ymm3, ymmword ptr [rax + 4*rsi]
	vmovups	ymm10, ymmword ptr [r11 + 4*rsi]
	vmovups	ymm13, ymmword ptr [r11 + 4*rsi + 32]
	add	rsi, 16
	cmp	rcx, rsi
	vsubps	ymm5, ymm10, ymm5
	vsubps	ymm9, ymm13, ymm9
	vfmadd231ps	ymm4, ymm5, ymm5        # ymm4 = (ymm5 * ymm5) + ymm4
	vfmadd231ps	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	jne	.LBB0_47
# %bb.48:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddps	ymm2, ymm2, ymm4
	cmp	r10, rcx
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	je	.LBB0_51
.LBB0_49:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, r15
	imul	rax, r14
	add	r8, rax
	.p2align	4, 0x90
.LBB0_50:                               # %L208
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm2, xmm7, dword ptr [r8 + 4*rcx]
	vmovss	xmm4, dword ptr [r11 + 4*rcx]   # xmm4 = mem[0],zero,zero,zero
	add	rcx, 1
	cmp	r10, rcx
	vsubss	xmm2, xmm4, xmm2
	vfmadd231ss	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	jne	.LBB0_50
.LBB0_51:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomiss	xmm12, xmm3
	ja	.LBB0_78
.LBB0_52:                               # %L250
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubss	xmm4, xmm6, xmm8
	vucomiss	xmm12, xmm4
	ja	.LBB0_79
# %bb.53:                               # %L257
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddss	xmm5, xmm8, xmm6
	vucomiss	xmm12, xmm5
	ja	.LBB0_80
# %bb.54:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vsqrtss	xmm4, xmm4, xmm4
	vsqrtss	xmm5, xmm5, xmm5
	vsqrtss	xmm2, xmm3, xmm3
	movabs	rsi, offset .LCPI0_5
	vmovss	dword ptr [rbx + 20], xmm11     # 4-byte Spill
	vmulss	xmm3, xmm4, xmm5
	vucomiss	xmm2, xmm12
	setnp	cl
	sete	al
	vmulss	xmm4, xmm6, xmm3
	vmovss	xmm3, dword ptr [rsi]           # xmm3 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm3
	jb	.LBB0_66
# %bb.55:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivss	xmm6, xmm2, xmm4
	movabs	rsi, offset .LCPI0_4
	and	al, cl
	vmovss	xmm4, dword ptr [rsi]           # xmm4 = mem[0],zero,zero,zero
	vmulss	xmm2, xmm8, xmm6
	vcmpleps	xmm9, xmm6, xmm4
	vcmpleps	xmm5, xmm3, xmm6
	vandps	xmm5, xmm9, xmm5
	vmovd	ecx, xmm5
	vcmpleps	xmm4, xmm2, xmm4
	vcmpleps	xmm3, xmm3, xmm2
	vandps	xmm3, xmm3, xmm4
	vmovd	esi, xmm3
	and	esi, ecx
	or	sil, al
	test	sil, 1
	je	.LBB0_66
# %bb.56:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_5
	vaddss	xmm3, xmm7, xmm0
	vucomiss	xmm2, dword ptr [rax]
	jb	.LBB0_59
# %bb.57:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_4
	vmovss	xmm0, dword ptr [rax]           # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm2
	jb	.LBB0_59
# %bb.58:                               # %L299
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_1
	mov	r11, qword ptr [rbx + 40]       # 8-byte Reload
	vmovss	xmm11, dword ptr [rbx + 20]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	vbroadcastss	xmm0, dword ptr [rax]
	vxorps	xmm0, xmm2, xmm0
	vmaxss	xmm0, xmm3, xmm0
	vminss	xmm0, xmm0, xmm2
	vsubss	xmm0, xmm3, xmm0
	vaddss	xmm3, xmm12, xmm0
	jmp	.LBB0_68
.LBB0_66:                               # %L356
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	qword ptr [rbx + 80], rdi
	mov	qword ptr [rbx + 200], rdi
	mov	rdi, qword ptr [rbx + 24]       # 8-byte Reload
	lea	rsi, [rbx + 200]
	lea	rcx, [rbx + 32]
	mov	r8, r12
	mov	qword ptr [rbx + 208], r15
	mov	qword ptr [rbx + 216], r12
	mov	qword ptr [rbx + 224], r9
	mov	qword ptr [rbx + 232], 1
	mov	qword ptr [rbx + 104], rax
	movabs	rax, offset j__sqrt_cold_2118
	mov	qword ptr [rbx + 96], rdx
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbx + 40]       # 8-byte Reload
	vmovss	xmm11, dword ptr [rbx + 20]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	vxorps	xmm12, xmm12, xmm12
	vmovaps	xmm3, xmm0
	jmp	.LBB0_68
.LBB0_59:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	movabs	rcx, offset .LCPI0_6
	vmovaps	xmm0, xmm6
	vmovaps	xmm1, xmm8
	vmovaps	xmmword ptr [rbx + 240], xmm6   # 16-byte Spill
	vmovss	dword ptr [rbx + 60], xmm3      # 4-byte Spill
	vmovss	xmm2, dword ptr [rcx]           # xmm2 = mem[0],zero,zero,zero
	mov	qword ptr [rbx + 104], rax
	movabs	rax, offset j__exceptional_product_2117
	vzeroupper
	call	rax
	vmovss	xmm4, dword ptr [rbx + 60]      # 4-byte Reload
                                        # xmm4 = mem[0],zero,zero,zero
	vxorps	xmm1, xmm1, xmm1
	vsubss	xmm2, xmm4, xmm0
	vmovd	eax, xmm2
	vmovaps	xmm3, xmm2
	test	eax, eax
	jns	.LBB0_61
# %bb.60:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm3, xmm3, xmm3
.LBB0_61:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddss	xmm0, xmm4, xmm0
	vxorps	xmm4, xmm4, xmm4
	vmovd	eax, xmm0
	test	eax, eax
	jns	.LBB0_63
# %bb.62:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovaps	xmm4, xmm0
.LBB0_63:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpordss	xmm5, xmm2, xmm2
	vcmpordss	xmm6, xmm0, xmm0
	mov	r11, qword ptr [rbx + 40]       # 8-byte Reload
	vmovss	xmm11, dword ptr [rbx + 20]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	and	r13d, 2147483647
	vxorps	xmm12, xmm12, xmm12
	cmp	r13d, 2139095040
	vblendvps	xmm2, xmm2, xmm3, xmm5
	vblendvps	xmm0, xmm0, xmm4, xmm6
	vmovaps	xmm3, xmmword ptr [rbx + 240]   # 16-byte Reload
	vaddss	xmm0, xmm2, xmm0
	vmovaps	xmm2, xmm0
	jne	.LBB0_65
# %bb.64:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm2, xmm2, xmm2
.LBB0_65:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpnless	xmm1, xmm1, xmm3
	vblendvps	xmm3, xmm2, xmm0, xmm1
	jmp	.LBB0_68
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10, r10
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rdx, qword ptr [rcx]
	mov	r8, qword ptr [rcx + 24]
	mov	rsi, qword ptr [rax]
	cmp	r10, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=1
	mov	r13, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_20
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=1
	mov	r13, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_31
.LBB0_17:                               # %vector.ph426
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, 9223372036854775792
	movabs	rcx, offset .LCPI0_0
	lea	rdi, [rax + 8]
	mov	rax, r8
	vmovaps	ymm0, ymmword ptr [rcx]
	xor	ecx, ecx
	imul	rax, r14
	and	rdi, r10
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	add	rax, rdx
.LBB0_18:                               # %vector.body431
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rax + 4*rcx]
	vmovups	ymm4, ymmword ptr [rsi + 4*rcx]
	add	rcx, 8
	cmp	rdi, rcx
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_18
# %bb.19:                               # %middle.block423
                                        #   in Loop: Header=BB0_8 Depth=1
	vextractf128	xmm3, ymm2, 1
	mov	r13, qword ptr [rbx + 24]       # 8-byte Reload
	cmp	r10, rdi
	vaddps	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm1, 1
	vaddps	xmm1, xmm1, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddps	xmm1, xmm1, xmm3
	vaddps	xmm0, xmm0, xmm4
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm1              # xmm3 = xmm1[1,1,3,3]
	vmovshdup	xmm5, xmm0              # xmm5 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm1, xmm3
	vaddss	xmm1, xmm0, xmm5
	je	.LBB0_31
.LBB0_20:                               # %scalar.ph424
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, r14
	add	rdx, r8
.LBB0_21:                               # %L54
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rdx + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm3, dword ptr [rsi + 4*rdi]   # xmm3 = mem[0],zero,zero,zero
	add	rdi, 1
	cmp	r10, rdi
	vfmadd231ss	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231ss	xmm4, xmm3, xmm0        # xmm4 = (xmm3 * xmm0) + xmm4
	vfmadd231ss	xmm2, xmm3, xmm3        # xmm2 = (xmm3 * xmm3) + xmm2
	jne	.LBB0_21
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_69:
	mov	rcx, qword ptr [rbx + 144]      # 8-byte Reload
	mov	rax, rsi
.LBB0_70:                               # %L374
                                        # =>This Inner Loop Header: Depth=1
	cmp	rcx, qword ptr [rbx + 136]      # 8-byte Folded Reload
	je	.LBB0_71
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_70 Depth=1
	mov	rsi, qword ptr [r11 + 8]
	add	rcx, 1
	test	rsi, rsi
	jne	.LBB0_7
	jmp	.LBB0_70
.LBB0_1:
	vxorps	xmm11, xmm11, xmm11
	jmp	.LBB0_72
.LBB0_3:
	vxorps	xmm11, xmm11, xmm11
                                        # implicit-def: $rax
                                        # implicit-def: $r15
.LBB0_71:                               # %L385.loopexit
	mov	rcx, qword ptr [rbx + 128]      # 8-byte Reload
	mov	qword ptr [rbx + 112], r15
	mov	qword ptr [rbx + 120], rax
.LBB0_72:                               # %L385
	mov	rax, qword ptr [rbx + 72]
	vmovaps	xmm0, xmm11
	mov	qword ptr [rcx], rax
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_9:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_73
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_73:                               # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r12
	vzeroupper
	call	rax
.LBB0_32:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_74
.LBB0_34:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_34
.LBB0_74:                               # %oob44
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r11
	mov	qword ptr [rsi], r12
	vzeroupper
	call	rax
.LBB0_76:                               # %L145
	movabs	rax, offset j_throw_boundserror_2119
	lea	rsi, [rbx + 112]
	mov	qword ptr [rbx + 112], r15
	mov	qword ptr [rbx + 120], r12
	mov	qword ptr [rbx + 96], rdi
	vzeroupper
	call	rax
.LBB0_77:                               # %L182
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_79:                               # %L255
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_80:                               # %L262
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_78:                               # %L248
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_2112, .Lfunc_end0-julia_pass_2112
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
