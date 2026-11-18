	.text
	.file	"_sweep!"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia__sweep!_1828
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
	.long	0x00800000                      # float 1.17549435E-38
.LCPI0_5:
	.long	0x7f7fffff                      # float 3.40282347E+38
.LCPI0_6:
	.long	0x7fffffff                      # float NaN
	.text
	.globl	"julia__sweep!_1828"
	.p2align	4, 0x90
	.type	"julia__sweep!_1828",@function
"julia__sweep!_1828":                   # @"julia__sweep!_1828"
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
	mov	r14, r9
	mov	qword ptr [rbx + 32], rsi       # 8-byte Spill
	mov	dword ptr [rbx + 148], r8d      # 4-byte Spill
	mov	qword ptr [rbx + 176], rdx      # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 96], ymm0
	mov	qword ptr [rbx + 128], 0
	lea	rsi, [rbx + 96]
	mov	qword ptr [rbx + 24], rdi       # 8-byte Spill
	mov	rdx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 96], 12
	mov	rax, qword ptr [rdx]
	mov	qword ptr [rbx + 216], rdx      # 8-byte Spill
	mov	qword ptr [rbx + 104], rax
	mov	qword ptr [rdx], rsi
	mov	r15, qword ptr [r9 + 16]
	sub	r15, qword ptr [r9 + 8]
	lea	rax, [r15 + 1]
	mov	rdx, rax
	sar	rdx, 63
	andn	rsi, rdx, rax
	test	byte ptr [rcx], 1
	mov	qword ptr [rbx + 152], rsi      # 8-byte Spill
	jne	.LBB0_1
# %bb.102:                              # %L553
	movabs	rax, 9223372036854775792
	vxorps	xmm0, xmm0, xmm0
	add	rax, 14
	cmp	r15, rax
	ja	.LBB0_203
# %bb.103:                              # %L569.preheader
	movabs	rcx, offset .LCPI0_1
	mov	rax, qword ptr [r14]
	mov	rdx, qword ptr [r14 + 24]
	mov	r11, rdi
	vxorps	xmm10, xmm10, xmm10
	mov	r15d, 1
	vbroadcastss	ymm0, dword ptr [rcx]
	mov	qword ptr [rbx + 136], rax      # 8-byte Spill
	movabs	rax, offset .LCPI0_0
	mov	qword ptr [rbx + 160], rdx      # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 288], ymm0   # 32-byte Spill
	vmovaps	ymm0, ymmword ptr [rax]
                                        # implicit-def: $rax
                                        # kill: killed $rax
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vxorps	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_104:                              # %L569
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_114 Depth 2
                                        #     Child Loop BB0_117 Depth 2
                                        #     Child Loop BB0_123 Depth 2
                                        #     Child Loop BB0_126 Depth 2
                                        #     Child Loop BB0_133 Depth 2
                                        #     Child Loop BB0_153 Depth 2
                                        #     Child Loop BB0_156 Depth 2
                                        #     Child Loop BB0_191 Depth 2
                                        #     Child Loop BB0_194 Depth 2
	mov	rcx, qword ptr [rbx + 136]      # 8-byte Reload
	mov	rax, qword ptr [rbx + 160]      # 8-byte Reload
	mov	rcx, qword ptr [rcx]
	add	rax, r15
	mov	r14, qword ptr [rcx + 8*rax - 8]
	mov	rcx, qword ptr [rbx + 32]       # 8-byte Reload
	mov	r13, qword ptr [rcx]
	lea	r12, [r14 - 1]
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_105
# %bb.108:                              # %idxend301
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovss	dword ptr [rbx + 92], xmm0      # 4-byte Spill
	vmovss	xmm11, dword ptr [rax + 4*r14 - 4] # xmm11 = mem[0],zero,zero,zero
	mov	rax, qword ptr [r13]
	mov	r10, qword ptr [rdi + 8]
	vucomiss	xmm11, xmm11
	jp	.LBB0_109
# %bb.118:                              # %L648
                                        #   in Loop: Header=BB0_104 Depth=1
	test	r10, r10
	je	.LBB0_119
# %bb.120:                              # %L661.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r10, 16
	jae	.LBB0_122
# %bb.121:                              #   in Loop: Header=BB0_104 Depth=1
	vxorps	xmm2, xmm2, xmm2
	xor	edx, edx
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_125
	.p2align	4, 0x90
.LBB0_119:                              #   in Loop: Header=BB0_104 Depth=1
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_127
	.p2align	4, 0x90
.LBB0_122:                              # %vector.ph1599
                                        #   in Loop: Header=BB0_104 Depth=1
	vmovaps	ymm2, ymmword ptr [rbx + 256]   # 32-byte Reload
	vmovaps	ymm3, ymmword ptr [rbx + 288]   # 32-byte Reload
	mov	rdx, r10
	movabs	rax, 9223372036854775792
	lea	rsi, [r8 + 4*r9 + 32]
	and	rdx, rax
	xor	eax, eax
	vmovaps	ymm0, ymm2
	vmovaps	ymm1, ymm3
	.p2align	4, 0x90
.LBB0_123:                              # %vector.body1604
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm4, ymmword ptr [rcx + 4*rax]
	vmovups	ymm5, ymmword ptr [rcx + 4*rax + 32]
	vfmadd231ps	ymm0, ymm4, ymmword ptr [rsi + 4*rax - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rsi + 4*rax] # ymm1 = (ymm5 * mem) + ymm1
	add	rax, 16
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rdx, rax
	jne	.LBB0_123
# %bb.124:                              # %middle.block1596
                                        #   in Loop: Header=BB0_104 Depth=1
	vaddps	ymm2, ymm3, ymm2
	vaddps	ymm0, ymm1, ymm0
	cmp	r10, rdx
	vextractf128	xmm1, ymm2, 1
	vaddps	xmm1, xmm2, xmm1
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddps	xmm1, xmm1, xmm2
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm6, xmm1, xmm2
	vaddss	xmm2, xmm0, xmm3
	je	.LBB0_127
.LBB0_125:                              # %scalar.ph1597
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rax, [r8 + 4*r9]
	.p2align	4, 0x90
.LBB0_126:                              # %L661
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm2, xmm0, dword ptr [rax + 4*rdx] # xmm2 = (xmm0 * mem) + xmm2
	add	rdx, 1
	vfmadd231ss	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r10, rdx
	jne	.LBB0_126
.LBB0_127:                              # %L689
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubss	xmm3, xmm6, xmm6
	vucomiss	xmm3, xmm3
	jp	.LBB0_128
.LBB0_129:                              # %L696
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm11, xmm10
	jne	.LBB0_135
	jp	.LBB0_135
# %bb.130:                              # %L698
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_135
# %bb.131:                              # %L711.preheader
                                        #   in Loop: Header=BB0_104 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_218
# %bb.132:                              # %ib347.us.preheader
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, rax
	mov	rdx, qword ptr [rdi]
	imul	rcx, r12
	lea	rcx, [rdx + 4*rcx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_133:                              # %ib347.us
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm10
	jne	.LBB0_239
	jp	.LBB0_239
# %bb.134:                              # %L717.us
                                        #   in Loop: Header=BB0_133 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_133
.LBB0_135:                              # %L737
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubss	xmm0, xmm11, xmm11
	vucomiss	xmm0, xmm0
	jp	.LBB0_246
# %bb.136:                              # %L742
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_240
# %bb.137:                              # %L756
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_138
# %bb.139:                              # %L761
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	xmm0, dword ptr [rcx + 4*rax - 4] # xmm0 = mem[0],zero,zero,zero
	jmp	.LBB0_140
	.p2align	4, 0x90
.LBB0_138:                              #   in Loop: Header=BB0_104 Depth=1
	vxorps	xmm0, xmm0, xmm0
.LBB0_140:                              # %L766
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm11, xmm10
	vmovss	dword ptr [rbx + 64], xmm0      # 4-byte Spill
	jne	.LBB0_142
	jnp	.LBB0_141
.LBB0_142:                              # %L770
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vcvtsi2ss	xmm1, xmm13, rax
	vmulss	xmm1, xmm1, dword ptr [rsi]
	vucomiss	xmm11, xmm1
	jb	.LBB0_170
# %bb.143:                              # %L770
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm3, xmm3
	jp	.LBB0_170
# %bb.144:                              # %L770
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm6, xmm1
	jb	.LBB0_170
# %bb.145:                              # %L789
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm10, xmm11
	ja	.LBB0_241
# %bb.146:                              # %L795
                                        #   in Loop: Header=BB0_104 Depth=1
	vsqrtss	xmm5, xmm11, xmm11
	mov	rsi, qword ptr [rbx + 32]       # 8-byte Reload
	vxorps	xmm0, xmm0, xmm0
	vmovss	xmm4, dword ptr [rsi + 8]       # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm5
	jae	.LBB0_171
# %bb.147:                              # %L800
                                        #   in Loop: Header=BB0_104 Depth=1
	vdivss	xmm3, xmm2, xmm11
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm0, xmm2, xmm3
	vmulss	xmm2, xmm6, dword ptr [rsi]
	vsubss	xmm0, xmm6, xmm0
	vucomiss	xmm2, xmm0
	jbe	.LBB0_160
# %bb.148:                              # %L807
                                        #   in Loop: Header=BB0_104 Depth=1
	test	rax, rax
	je	.LBB0_149
# %bb.150:                              # %L821.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	r9, qword ptr [rsi + 24]
	mov	r8, qword ptr [rsi]
	imul	r9, r12
	cmp	rax, 16
	jae	.LBB0_152
# %bb.151:                              #   in Loop: Header=BB0_104 Depth=1
	vxorps	xmm0, xmm0, xmm0
	xor	edx, edx
	jmp	.LBB0_155
	.p2align	4, 0x90
.LBB0_141:                              # %L768
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx + 176]      # 8-byte Reload
	mov	rsi, r14
	movabs	rax, offset j__coordinate_minimizer_1832
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 48], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 48]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_171
	.p2align	4, 0x90
.LBB0_170:                              # %L967
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1837
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 48], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 48]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
.LBB0_171:                              # %L970
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_172
# %bb.175:                              # %idxend384
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubss	xmm1, xmm0, dword ptr [rbx + 64] # 4-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovss	dword ptr [rax + 4*r14 - 4], xmm11
	vucomiss	xmm1, xmm10
	jne	.LBB0_176
	jnp	.LBB0_196
.LBB0_176:                              # %L978
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_245
# %bb.177:                              # %L992
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_182
# %bb.178:                              # %L997
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	dword ptr [rcx + 4*rax - 4], xmm0
	jmp	.LBB0_179
	.p2align	4, 0x90
.LBB0_182:                              # %L1000
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm0, xmm10
	jne	.LBB0_183
	jnp	.LBB0_179
.LBB0_183:                              # %L1003
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdx, qword ptr [r11 + 24]
	lea	rax, [rdx + 1]
	mov	qword ptr [r11 + 24], rax
	mov	rdi, qword ptr [r11]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_184
# %bb.224:                              # %idxend440
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovss	dword ptr [rsi + 4*rdx], xmm0
	mov	rdi, qword ptr [r11 + 8]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_225
# %bb.229:                              # %idxend460
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rdx], r14
	mov	qword ptr [rcx + 8*r14 - 8], rax
	.p2align	4, 0x90
.LBB0_179:                              # %L1017
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 40], r14       # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_196
# %bb.180:                              # %L1030.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	imul	r12, qword ptr [rdx + 24]
	mov	r8, qword ptr [rdx]
	cmp	rax, 32
	jae	.LBB0_187
# %bb.181:                              #   in Loop: Header=BB0_104 Depth=1
	xor	esi, esi
	jmp	.LBB0_193
.LBB0_187:                              # %vector.memcheck1535
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rdx, [rax + r12]
	lea	rdx, [r8 + 4*rdx]
	cmp	rcx, rdx
	jae	.LBB0_190
# %bb.188:                              # %vector.memcheck1535
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rdx, [rcx + 4*rax]
	lea	rsi, [r8 + 4*r12]
	cmp	rsi, rdx
	jae	.LBB0_190
# %bb.189:                              #   in Loop: Header=BB0_104 Depth=1
	xor	esi, esi
	jmp	.LBB0_193
.LBB0_190:                              # %vector.ph1549
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rdx, 9223372036854775792
	vbroadcastss	ymm0, xmm1
	lea	rdi, [r8 + 4*r12 + 96]
	lea	rsi, [rdx - 16]
	xor	edx, edx
	and	rsi, rax
	.p2align	4, 0x90
.LBB0_191:                              # %vector.body1554
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm3, ymm0, ymmword ptr [rdi + 4*rdx - 64]
	vmulps	ymm2, ymm0, ymmword ptr [rdi + 4*rdx - 96]
	vmulps	ymm4, ymm0, ymmword ptr [rdi + 4*rdx - 32]
	vmulps	ymm5, ymm0, ymmword ptr [rdi + 4*rdx]
	vmovups	ymm7, ymmword ptr [rcx + 4*rdx + 32]
	vmovups	ymm6, ymmword ptr [rcx + 4*rdx]
	vmovups	ymm8, ymmword ptr [rcx + 4*rdx + 64]
	vsubps	ymm3, ymm7, ymm3
	vmovups	ymm7, ymmword ptr [rcx + 4*rdx + 96]
	vsubps	ymm2, ymm6, ymm2
	vsubps	ymm4, ymm8, ymm4
	vsubps	ymm5, ymm7, ymm5
	vmovups	ymmword ptr [rcx + 4*rdx], ymm2
	vmovups	ymmword ptr [rcx + 4*rdx + 32], ymm3
	vmovups	ymmword ptr [rcx + 4*rdx + 64], ymm4
	vmovups	ymmword ptr [rcx + 4*rdx + 96], ymm5
	add	rdx, 32
	cmp	rsi, rdx
	jne	.LBB0_191
# %bb.192:                              # %middle.block1546
                                        #   in Loop: Header=BB0_104 Depth=1
	cmp	rax, rsi
	mov	qword ptr [rbx + 40], r14       # 8-byte Spill
	je	.LBB0_196
	.p2align	4, 0x90
.LBB0_193:                              # %scalar.ph1547
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rdx, [r8 + 4*r12]
	.p2align	4, 0x90
.LBB0_194:                              # %L1030
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm0, xmm1, dword ptr [rdx + 4*rsi]
	vmovss	xmm2, dword ptr [rcx + 4*rsi]   # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm0, xmm2, xmm0
	vmovss	dword ptr [rcx + 4*rsi], xmm0
	add	rsi, 1
	cmp	rax, rsi
	jne	.LBB0_194
# %bb.195:                              #   in Loop: Header=BB0_104 Depth=1
	mov	qword ptr [rbx + 40], r14       # 8-byte Spill
.LBB0_196:                              # %L1054
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rax, offset .LCPI0_6
	test	byte ptr [rbx + 148], 1         # 1-byte Folded Reload
	vbroadcastss	xmm0, dword ptr [rax]
	vandps	xmm2, xmm1, xmm0
	je	.LBB0_197
# %bb.198:                              # %L1054
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm1, xmm10
	mov	r12, qword ptr [rbx + 152]      # 8-byte Reload
	jne	.LBB0_199
	jnp	.LBB0_200
.LBB0_199:                              # %L1060
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r11
	mov	rdx, r14
	vmovaps	xmmword ptr [rbx + 64], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_1833
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovaps	xmm2, xmmword ptr [rbx + 64]    # 16-byte Reload
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	vmulss	xmm2, xmm2, xmm0
	jmp	.LBB0_200
	.p2align	4, 0x90
.LBB0_197:                              #   in Loop: Header=BB0_104 Depth=1
	mov	r12, qword ptr [rbx + 152]      # 8-byte Reload
.LBB0_200:                              # %L1065
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubss	xmm0, xmm2, xmm2
	vucomiss	xmm0, xmm0
	jp	.LBB0_247
# %bb.201:                              # %L1074
                                        #   in Loop: Header=BB0_104 Depth=1
	vmovss	xmm0, dword ptr [rbx + 92]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	cmp	r15, r12
	lea	r15, [r15 + 1]
	vmaxss	xmm0, xmm2, xmm0
	jne	.LBB0_104
	jmp	.LBB0_202
.LBB0_149:                              #   in Loop: Header=BB0_104 Depth=1
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_157
.LBB0_152:                              # %vector.ph1576
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rdx, offset .LCPI0_1
	movabs	rsi, 9223372036854775792
	vbroadcastss	ymm6, xmm3
	lea	rdi, [r8 + 4*r9 + 32]
	vbroadcastss	ymm0, dword ptr [rdx]
	mov	rdx, rax
	and	rdx, rsi
	movabs	rsi, offset .LCPI0_0
	vmovaps	ymm2, ymmword ptr [rsi]
	xor	esi, esi
	.p2align	4, 0x90
.LBB0_153:                              # %vector.body1581
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm7, ymm6, ymmword ptr [rdi + 4*rsi - 32]
	vmulps	ymm8, ymm6, ymmword ptr [rdi + 4*rsi]
	vmovups	ymm9, ymmword ptr [rcx + 4*rsi]
	vmovups	ymm12, ymmword ptr [rcx + 4*rsi + 32]
	add	rsi, 16
	cmp	rdx, rsi
	vsubps	ymm7, ymm9, ymm7
	vsubps	ymm8, ymm12, ymm8
	vfmadd231ps	ymm2, ymm7, ymm7        # ymm2 = (ymm7 * ymm7) + ymm2
	vfmadd231ps	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	jne	.LBB0_153
# %bb.154:                              # %middle.block1573
                                        #   in Loop: Header=BB0_104 Depth=1
	vaddps	ymm0, ymm0, ymm2
	cmp	rax, rdx
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm2
	je	.LBB0_157
.LBB0_155:                              # %scalar.ph1574
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rsi, [r8 + 4*r9]
	.p2align	4, 0x90
.LBB0_156:                              # %L821
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm2, xmm3, dword ptr [rsi + 4*rdx]
	vmovss	xmm6, dword ptr [rcx + 4*rdx]   # xmm6 = mem[0],zero,zero,zero
	add	rdx, 1
	cmp	rax, rdx
	vsubss	xmm2, xmm6, xmm2
	vfmadd231ss	xmm0, xmm2, xmm2        # xmm0 = (xmm2 * xmm2) + xmm0
	jne	.LBB0_156
.LBB0_157:                              # %L844
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm0, xmm1
	jb	.LBB0_159
# %bb.158:                              # %L844
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubss	xmm1, xmm0, xmm0
	vucomiss	xmm1, xmm1
	jp	.LBB0_159
.LBB0_160:                              # %L855
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm10, xmm0
	ja	.LBB0_242
# %bb.161:                              # %L860
                                        #   in Loop: Header=BB0_104 Depth=1
	vsubss	xmm1, xmm5, xmm4
	vucomiss	xmm10, xmm1
	ja	.LBB0_243
# %bb.162:                              # %L867
                                        #   in Loop: Header=BB0_104 Depth=1
	vaddss	xmm2, xmm5, xmm4
	vucomiss	xmm10, xmm2
	ja	.LBB0_244
# %bb.163:                              # %L874
                                        #   in Loop: Header=BB0_104 Depth=1
	vsqrtss	xmm1, xmm1, xmm1
	vsqrtss	xmm2, xmm2, xmm2
	movabs	rax, offset .LCPI0_4
	vmulss	xmm1, xmm1, xmm2
	vmulss	xmm1, xmm5, xmm1
	vucomiss	xmm1, dword ptr [rax]
	jb	.LBB0_169
# %bb.164:                              # %L874
                                        #   in Loop: Header=BB0_104 Depth=1
	vsqrtss	xmm0, xmm0, xmm0
	movabs	rax, offset .LCPI0_4
	vdivss	xmm0, xmm0, xmm1
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_169
# %bb.165:                              # %L874
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rax, offset .LCPI0_5
	vmovss	xmm1, dword ptr [rax]           # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm0
	jb	.LBB0_169
# %bb.166:                              # %L874
                                        #   in Loop: Header=BB0_104 Depth=1
	vmulss	xmm0, xmm4, xmm0
	movabs	rax, offset .LCPI0_4
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_169
# %bb.167:                              # %L874
                                        #   in Loop: Header=BB0_104 Depth=1
	vucomiss	xmm1, xmm0
	jb	.LBB0_169
# %bb.168:                              # %L908
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rax, offset .LCPI0_1
	vaddss	xmm2, xmm3, dword ptr [rbx + 64] # 4-byte Folded Reload
	vbroadcastss	xmm1, dword ptr [rax]
	vxorps	xmm1, xmm0, xmm1
	vmaxss	xmm1, xmm2, xmm1
	vminss	xmm0, xmm1, xmm0
	vsubss	xmm0, xmm2, xmm0
	vaddss	xmm0, xmm10, xmm0
	jmp	.LBB0_171
.LBB0_169:                              # %L965
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 64]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1837
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 48], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 48]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_171
.LBB0_159:                              # %L853
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 64]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1837
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 48], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 48]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_171
.LBB0_109:                              # %L605
                                        #   in Loop: Header=BB0_104 Depth=1
	test	r10, r10
	je	.LBB0_110
# %bb.111:                              # %L619.lr.ph
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r10, 8
	jae	.LBB0_113
# %bb.112:                              #   in Loop: Header=BB0_104 Depth=1
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm11, xmm11, xmm11
	xor	edx, edx
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_116
.LBB0_128:                              # %L694
                                        #   in Loop: Header=BB0_104 Depth=1
	mov	rsi, r14
	movabs	rax, offset j__check_residual_1839
	mov	qword ptr [rbx + 120], r13
	mov	qword ptr [rbx + 112], rdi
	vmovss	dword ptr [rbx + 48], xmm11     # 4-byte Spill
	vmovss	dword ptr [rbx + 64], xmm6      # 4-byte Spill
	vmovss	dword ptr [rbx + 224], xmm2     # 4-byte Spill
	vmovss	dword ptr [rbx + 88], xmm3      # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm3, dword ptr [rbx + 88]      # 4-byte Reload
                                        # xmm3 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rbx + 224]     # 4-byte Reload
                                        # xmm2 = mem[0],zero,zero,zero
	vmovss	xmm6, dword ptr [rbx + 64]      # 4-byte Reload
                                        # xmm6 = mem[0],zero,zero,zero
	vmovss	xmm11, dword ptr [rbx + 48]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_129
.LBB0_110:                              #   in Loop: Header=BB0_104 Depth=1
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm11, xmm11, xmm11
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_127
.LBB0_113:                              # %vector.ph1622
                                        #   in Loop: Header=BB0_104 Depth=1
	movabs	rsi, offset .LCPI0_0
	movabs	rax, 9223372036854775792
	vmovaps	ymm0, ymmword ptr [rsi]
	lea	rdx, [rax + 8]
	lea	rax, [r8 + 4*r9]
	xor	esi, esi
	and	rdx, r10
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
.LBB0_114:                              # %vector.body1627
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rax + 4*rsi]
	vmovups	ymm4, ymmword ptr [rcx + 4*rsi]
	add	rsi, 8
	cmp	rdx, rsi
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_114
# %bb.115:                              # %middle.block1619
                                        #   in Loop: Header=BB0_104 Depth=1
	vextractf128	xmm3, ymm2, 1
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	cmp	r10, rdx
	vxorps	xmm10, xmm10, xmm10
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
	vaddss	xmm6, xmm2, xmm3
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm2, xmm1, xmm2
	vaddss	xmm11, xmm0, xmm3
	je	.LBB0_127
.LBB0_116:                              # %scalar.ph1620
                                        #   in Loop: Header=BB0_104 Depth=1
	lea	rax, [r8 + 4*r9]
.LBB0_117:                              # %L619
                                        #   Parent Loop BB0_104 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rax + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm1, dword ptr [rcx + 4*rdx]   # xmm1 = mem[0],zero,zero,zero
	add	rdx, 1
	cmp	r10, rdx
	vfmadd231ss	xmm11, xmm0, xmm0       # xmm11 = (xmm0 * xmm0) + xmm11
	vfmadd231ss	xmm2, xmm1, xmm0        # xmm2 = (xmm1 * xmm0) + xmm2
	vfmadd231ss	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_117
	jmp	.LBB0_127
.LBB0_1:                                # %L12
	mov	rdi, qword ptr [rcx + 8]
	movabs	rax, offset "j__shuffle!_1830"
	movabs	r12, 9223372036854775792
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	mov	qword ptr [rbx + 64], rax       # 8-byte Spill
	lea	rax, [r12 + 14]
	vxorps	xmm0, xmm0, xmm0
	cmp	r15, rax
	ja	.LBB0_203
# %bb.2:                                # %L30.preheader
	movabs	rcx, offset .LCPI0_1
	mov	rax, qword ptr [r14]
	mov	rdx, qword ptr [r14 + 24]
	vxorps	xmm10, xmm10, xmm10
	mov	r15d, 1
	vbroadcastss	ymm0, dword ptr [rcx]
	mov	qword ptr [rbx + 160], rax      # 8-byte Spill
	movabs	rax, offset .LCPI0_0
	mov	qword ptr [rbx + 288], rdx      # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vmovaps	ymm0, ymmword ptr [rax]
                                        # implicit-def: $rax
                                        # kill: killed $rax
	vmovaps	ymmword ptr [rbx + 224], ymm0   # 32-byte Spill
	vxorps	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_3:                                # %L30
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_13 Depth 2
                                        #     Child Loop BB0_16 Depth 2
                                        #     Child Loop BB0_22 Depth 2
                                        #     Child Loop BB0_25 Depth 2
                                        #     Child Loop BB0_32 Depth 2
                                        #     Child Loop BB0_52 Depth 2
                                        #     Child Loop BB0_55 Depth 2
                                        #     Child Loop BB0_90 Depth 2
                                        #     Child Loop BB0_93 Depth 2
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 160]      # 8-byte Reload
	mov	rax, qword ptr [rax]
	mov	rcx, qword ptr [rcx]
	mov	rax, qword ptr [rax + 8*r15 - 8]
	add	rax, qword ptr [rbx + 288]      # 8-byte Folded Reload
	mov	r14, qword ptr [rcx + 8*rax - 8]
	mov	rcx, qword ptr [rbx + 32]       # 8-byte Reload
	mov	r13, qword ptr [rcx]
	lea	r12, [r14 - 1]
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_4
# %bb.7:                                # %idxend
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovss	dword ptr [rbx + 92], xmm0      # 4-byte Spill
	vmovss	xmm11, dword ptr [rax + 4*r14 - 4] # xmm11 = mem[0],zero,zero,zero
	mov	rax, qword ptr [r13]
	mov	r10, qword ptr [rdi + 8]
	vucomiss	xmm11, xmm11
	jp	.LBB0_8
# %bb.17:                               # %L110
                                        #   in Loop: Header=BB0_3 Depth=1
	test	r10, r10
	je	.LBB0_18
# %bb.19:                               # %L123.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r10, 16
	jae	.LBB0_21
# %bb.20:                               #   in Loop: Header=BB0_3 Depth=1
	vxorps	xmm2, xmm2, xmm2
	xor	edx, edx
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_24
	.p2align	4, 0x90
.LBB0_18:                               #   in Loop: Header=BB0_3 Depth=1
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_26
	.p2align	4, 0x90
.LBB0_21:                               # %vector.ph1496
                                        #   in Loop: Header=BB0_3 Depth=1
	vmovaps	ymm2, ymmword ptr [rbx + 224]   # 32-byte Reload
	vmovaps	ymm3, ymmword ptr [rbx + 256]   # 32-byte Reload
	mov	rdx, r10
	movabs	rax, 9223372036854775792
	lea	rsi, [r8 + 4*r9 + 32]
	and	rdx, rax
	xor	eax, eax
	vmovaps	ymm0, ymm2
	vmovaps	ymm1, ymm3
	.p2align	4, 0x90
.LBB0_22:                               # %vector.body1501
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm4, ymmword ptr [rcx + 4*rax]
	vmovups	ymm5, ymmword ptr [rcx + 4*rax + 32]
	vfmadd231ps	ymm0, ymm4, ymmword ptr [rsi + 4*rax - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rsi + 4*rax] # ymm1 = (ymm5 * mem) + ymm1
	add	rax, 16
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rdx, rax
	jne	.LBB0_22
# %bb.23:                               # %middle.block1493
                                        #   in Loop: Header=BB0_3 Depth=1
	vaddps	ymm2, ymm3, ymm2
	vaddps	ymm0, ymm1, ymm0
	cmp	r10, rdx
	vextractf128	xmm1, ymm2, 1
	vaddps	xmm1, xmm2, xmm1
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddps	xmm1, xmm1, xmm2
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm6, xmm1, xmm2
	vaddss	xmm2, xmm0, xmm3
	je	.LBB0_26
.LBB0_24:                               # %scalar.ph1494
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rax, [r8 + 4*r9]
	.p2align	4, 0x90
.LBB0_25:                               # %L123
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm2, xmm0, dword ptr [rax + 4*rdx] # xmm2 = (xmm0 * mem) + xmm2
	add	rdx, 1
	vfmadd231ss	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r10, rdx
	jne	.LBB0_25
.LBB0_26:                               # %L151
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubss	xmm3, xmm6, xmm6
	vucomiss	xmm3, xmm3
	jp	.LBB0_27
.LBB0_28:                               # %L158
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm11, xmm10
	jne	.LBB0_34
	jp	.LBB0_34
# %bb.29:                               # %L160
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_34
# %bb.30:                               # %L173.preheader
                                        #   in Loop: Header=BB0_3 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_205
# %bb.31:                               # %ib.us.preheader
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, rax
	mov	rdx, qword ptr [rdi]
	imul	rcx, r12
	lea	rcx, [rdx + 4*rcx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_32:                               # %ib.us
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm10
	jne	.LBB0_230
	jp	.LBB0_230
# %bb.33:                               # %L179.us
                                        #   in Loop: Header=BB0_32 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_32
.LBB0_34:                               # %L199
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubss	xmm0, xmm11, xmm11
	vucomiss	xmm0, xmm0
	jp	.LBB0_237
# %bb.35:                               # %L204
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_231
# %bb.36:                               # %L218
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_37
# %bb.38:                               # %L223
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	xmm0, dword ptr [rcx + 4*rax - 4] # xmm0 = mem[0],zero,zero,zero
	jmp	.LBB0_39
	.p2align	4, 0x90
.LBB0_37:                               #   in Loop: Header=BB0_3 Depth=1
	vxorps	xmm0, xmm0, xmm0
.LBB0_39:                               # %L228
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm11, xmm10
	vmovss	dword ptr [rbx + 48], xmm0      # 4-byte Spill
	jne	.LBB0_41
	jnp	.LBB0_40
.LBB0_41:                               # %L232
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vcvtsi2ss	xmm1, xmm13, rax
	vmulss	xmm1, xmm1, dword ptr [rsi]
	vucomiss	xmm11, xmm1
	jb	.LBB0_69
# %bb.42:                               # %L232
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm3, xmm3
	jp	.LBB0_69
# %bb.43:                               # %L232
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm6, xmm1
	jb	.LBB0_69
# %bb.44:                               # %L251
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm10, xmm11
	ja	.LBB0_232
# %bb.45:                               # %L257
                                        #   in Loop: Header=BB0_3 Depth=1
	vsqrtss	xmm5, xmm11, xmm11
	mov	rsi, qword ptr [rbx + 32]       # 8-byte Reload
	vxorps	xmm0, xmm0, xmm0
	vmovss	xmm4, dword ptr [rsi + 8]       # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm5
	jae	.LBB0_70
# %bb.46:                               # %L262
                                        #   in Loop: Header=BB0_3 Depth=1
	vdivss	xmm3, xmm2, xmm11
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm0, xmm2, xmm3
	vmulss	xmm2, xmm6, dword ptr [rsi]
	vsubss	xmm0, xmm6, xmm0
	vucomiss	xmm2, xmm0
	jbe	.LBB0_59
# %bb.47:                               # %L269
                                        #   in Loop: Header=BB0_3 Depth=1
	test	rax, rax
	je	.LBB0_48
# %bb.49:                               # %L283.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	r9, qword ptr [rsi + 24]
	mov	r8, qword ptr [rsi]
	imul	r9, r12
	cmp	rax, 16
	jae	.LBB0_51
# %bb.50:                               #   in Loop: Header=BB0_3 Depth=1
	vxorps	xmm0, xmm0, xmm0
	xor	edx, edx
	jmp	.LBB0_54
	.p2align	4, 0x90
.LBB0_40:                               # %L230
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 176]      # 8-byte Reload
	mov	rsi, r14
	vmovss	dword ptr [rbx + 40], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__coordinate_minimizer_1832
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 40]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_70
	.p2align	4, 0x90
.LBB0_69:                               # %L429
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rsi, r14
	vmovss	dword ptr [rbx + 40], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_1837
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 40]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
.LBB0_70:                               # %L432
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_71
# %bb.74:                               # %idxend101
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubss	xmm1, xmm0, dword ptr [rbx + 48] # 4-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovss	dword ptr [rax + 4*r14 - 4], xmm11
	vucomiss	xmm1, xmm10
	jne	.LBB0_75
	jnp	.LBB0_95
.LBB0_75:                               # %L440
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_236
# %bb.76:                               # %L454
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r14 - 8]
	test	rax, rax
	je	.LBB0_81
# %bb.77:                               # %L459
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	dword ptr [rcx + 4*rax - 4], xmm0
	jmp	.LBB0_78
	.p2align	4, 0x90
.LBB0_81:                               # %L462
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm0, xmm10
	jne	.LBB0_82
	jnp	.LBB0_78
.LBB0_82:                               # %L465
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdx, qword ptr [r11 + 24]
	lea	rax, [rdx + 1]
	mov	qword ptr [r11 + 24], rax
	mov	rdi, qword ptr [r11]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_83
# %bb.211:                              # %idxend159
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovss	dword ptr [rsi + 4*rdx], xmm0
	mov	rdi, qword ptr [r11 + 8]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_212
# %bb.216:                              # %idxend179
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rdx], r14
	mov	qword ptr [rcx + 8*r14 - 8], rax
	.p2align	4, 0x90
.LBB0_78:                               # %L479
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 136], r14      # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_95
# %bb.79:                               # %L492.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	imul	r12, qword ptr [rdx + 24]
	mov	r8, qword ptr [rdx]
	cmp	rax, 32
	jae	.LBB0_86
# %bb.80:                               #   in Loop: Header=BB0_3 Depth=1
	xor	esi, esi
	jmp	.LBB0_92
.LBB0_86:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rdx, [rax + r12]
	lea	rdx, [r8 + 4*rdx]
	cmp	rcx, rdx
	jae	.LBB0_89
# %bb.87:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rdx, [rcx + 4*rax]
	lea	rsi, [r8 + 4*r12]
	cmp	rsi, rdx
	jae	.LBB0_89
# %bb.88:                               #   in Loop: Header=BB0_3 Depth=1
	xor	esi, esi
	jmp	.LBB0_92
.LBB0_89:                               # %vector.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rdx, 9223372036854775792
	vbroadcastss	ymm0, xmm1
	lea	rdi, [r8 + 4*r12 + 96]
	lea	rsi, [rdx - 16]
	xor	edx, edx
	and	rsi, rax
	.p2align	4, 0x90
.LBB0_90:                               # %vector.body
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm3, ymm0, ymmword ptr [rdi + 4*rdx - 64]
	vmulps	ymm2, ymm0, ymmword ptr [rdi + 4*rdx - 96]
	vmulps	ymm4, ymm0, ymmword ptr [rdi + 4*rdx - 32]
	vmulps	ymm5, ymm0, ymmword ptr [rdi + 4*rdx]
	vmovups	ymm7, ymmword ptr [rcx + 4*rdx + 32]
	vmovups	ymm6, ymmword ptr [rcx + 4*rdx]
	vmovups	ymm8, ymmword ptr [rcx + 4*rdx + 64]
	vsubps	ymm3, ymm7, ymm3
	vmovups	ymm7, ymmword ptr [rcx + 4*rdx + 96]
	vsubps	ymm2, ymm6, ymm2
	vsubps	ymm4, ymm8, ymm4
	vsubps	ymm5, ymm7, ymm5
	vmovups	ymmword ptr [rcx + 4*rdx], ymm2
	vmovups	ymmword ptr [rcx + 4*rdx + 32], ymm3
	vmovups	ymmword ptr [rcx + 4*rdx + 64], ymm4
	vmovups	ymmword ptr [rcx + 4*rdx + 96], ymm5
	add	rdx, 32
	cmp	rsi, rdx
	jne	.LBB0_90
# %bb.91:                               # %middle.block
                                        #   in Loop: Header=BB0_3 Depth=1
	cmp	rax, rsi
	mov	qword ptr [rbx + 136], r14      # 8-byte Spill
	je	.LBB0_95
	.p2align	4, 0x90
.LBB0_92:                               # %scalar.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rdx, [r8 + 4*r12]
	.p2align	4, 0x90
.LBB0_93:                               # %L492
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm0, xmm1, dword ptr [rdx + 4*rsi]
	vmovss	xmm2, dword ptr [rcx + 4*rsi]   # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm0, xmm2, xmm0
	vmovss	dword ptr [rcx + 4*rsi], xmm0
	add	rsi, 1
	cmp	rax, rsi
	jne	.LBB0_93
# %bb.94:                               #   in Loop: Header=BB0_3 Depth=1
	mov	qword ptr [rbx + 136], r14      # 8-byte Spill
.LBB0_95:                               # %L516
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rax, offset .LCPI0_6
	test	byte ptr [rbx + 148], 1         # 1-byte Folded Reload
	vbroadcastss	xmm0, dword ptr [rax]
	vandps	xmm2, xmm1, xmm0
	je	.LBB0_96
# %bb.97:                               # %L516
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm1, xmm10
	mov	r12, qword ptr [rbx + 152]      # 8-byte Reload
	jne	.LBB0_98
	jnp	.LBB0_99
.LBB0_98:                               # %L522
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rsi, r11
	mov	rdx, r14
	vmovaps	xmmword ptr [rbx + 48], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_1833
	mov	qword ptr [rbx + 120], rcx
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovaps	xmm2, xmmword ptr [rbx + 48]    # 16-byte Reload
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	vmulss	xmm2, xmm2, xmm0
	jmp	.LBB0_99
	.p2align	4, 0x90
.LBB0_96:                               #   in Loop: Header=BB0_3 Depth=1
	mov	r12, qword ptr [rbx + 152]      # 8-byte Reload
.LBB0_99:                               # %L527
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubss	xmm0, xmm2, xmm2
	vucomiss	xmm0, xmm0
	jp	.LBB0_238
# %bb.100:                              # %L536
                                        #   in Loop: Header=BB0_3 Depth=1
	vmovss	xmm0, dword ptr [rbx + 92]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	cmp	r15, r12
	lea	r15, [r15 + 1]
	vmaxss	xmm0, xmm2, xmm0
	jne	.LBB0_3
	jmp	.LBB0_101
.LBB0_48:                               #   in Loop: Header=BB0_3 Depth=1
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_56
.LBB0_51:                               # %vector.ph1476
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rdx, offset .LCPI0_1
	movabs	rsi, 9223372036854775792
	vbroadcastss	ymm6, xmm3
	lea	rdi, [r8 + 4*r9 + 32]
	vbroadcastss	ymm0, dword ptr [rdx]
	mov	rdx, rax
	and	rdx, rsi
	movabs	rsi, offset .LCPI0_0
	vmovaps	ymm2, ymmword ptr [rsi]
	xor	esi, esi
	.p2align	4, 0x90
.LBB0_52:                               # %vector.body1481
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm7, ymm6, ymmword ptr [rdi + 4*rsi - 32]
	vmulps	ymm8, ymm6, ymmword ptr [rdi + 4*rsi]
	vmovups	ymm9, ymmword ptr [rcx + 4*rsi]
	vmovups	ymm12, ymmword ptr [rcx + 4*rsi + 32]
	add	rsi, 16
	cmp	rdx, rsi
	vsubps	ymm7, ymm9, ymm7
	vsubps	ymm8, ymm12, ymm8
	vfmadd231ps	ymm2, ymm7, ymm7        # ymm2 = (ymm7 * ymm7) + ymm2
	vfmadd231ps	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	jne	.LBB0_52
# %bb.53:                               # %middle.block1473
                                        #   in Loop: Header=BB0_3 Depth=1
	vaddps	ymm0, ymm0, ymm2
	cmp	rax, rdx
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm2
	je	.LBB0_56
.LBB0_54:                               # %scalar.ph1474
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rsi, [r8 + 4*r9]
	.p2align	4, 0x90
.LBB0_55:                               # %L283
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm2, xmm3, dword ptr [rsi + 4*rdx]
	vmovss	xmm6, dword ptr [rcx + 4*rdx]   # xmm6 = mem[0],zero,zero,zero
	add	rdx, 1
	cmp	rax, rdx
	vsubss	xmm2, xmm6, xmm2
	vfmadd231ss	xmm0, xmm2, xmm2        # xmm0 = (xmm2 * xmm2) + xmm0
	jne	.LBB0_55
.LBB0_56:                               # %L306
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm0, xmm1
	jb	.LBB0_58
# %bb.57:                               # %L306
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubss	xmm1, xmm0, xmm0
	vucomiss	xmm1, xmm1
	jp	.LBB0_58
.LBB0_59:                               # %L317
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm10, xmm0
	ja	.LBB0_233
# %bb.60:                               # %L322
                                        #   in Loop: Header=BB0_3 Depth=1
	vsubss	xmm1, xmm5, xmm4
	vucomiss	xmm10, xmm1
	ja	.LBB0_234
# %bb.61:                               # %L329
                                        #   in Loop: Header=BB0_3 Depth=1
	vaddss	xmm2, xmm5, xmm4
	vucomiss	xmm10, xmm2
	ja	.LBB0_235
# %bb.62:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vsqrtss	xmm1, xmm1, xmm1
	vsqrtss	xmm2, xmm2, xmm2
	movabs	rax, offset .LCPI0_4
	vmulss	xmm1, xmm1, xmm2
	vmulss	xmm1, xmm5, xmm1
	vucomiss	xmm1, dword ptr [rax]
	jb	.LBB0_68
# %bb.63:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vsqrtss	xmm0, xmm0, xmm0
	movabs	rax, offset .LCPI0_4
	vdivss	xmm0, xmm0, xmm1
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_68
# %bb.64:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rax, offset .LCPI0_5
	vmovss	xmm1, dword ptr [rax]           # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm0
	jb	.LBB0_68
# %bb.65:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vmulss	xmm0, xmm4, xmm0
	movabs	rax, offset .LCPI0_4
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_68
# %bb.66:                               # %L336
                                        #   in Loop: Header=BB0_3 Depth=1
	vucomiss	xmm1, xmm0
	jb	.LBB0_68
# %bb.67:                               # %L370
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rax, offset .LCPI0_1
	vaddss	xmm2, xmm3, dword ptr [rbx + 48] # 4-byte Folded Reload
	vbroadcastss	xmm1, dword ptr [rax]
	vxorps	xmm1, xmm0, xmm1
	vmaxss	xmm1, xmm2, xmm1
	vminss	xmm0, xmm1, xmm0
	vsubss	xmm0, xmm2, xmm0
	vaddss	xmm0, xmm10, xmm0
	jmp	.LBB0_70
.LBB0_68:                               # %L427
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 48]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r14
	vmovss	dword ptr [rbx + 40], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_1837
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 40]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_70
.LBB0_58:                               # %L315
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 32]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 48]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r14
	vmovss	dword ptr [rbx + 40], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_1837
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 40]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_70
.LBB0_8:                                # %L67
                                        #   in Loop: Header=BB0_3 Depth=1
	test	r10, r10
	je	.LBB0_9
# %bb.10:                               # %L81.lr.ph
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r10, 8
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_3 Depth=1
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm11, xmm11, xmm11
	xor	edx, edx
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_15
.LBB0_27:                               # %L156
                                        #   in Loop: Header=BB0_3 Depth=1
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rsi, r14
	vmovss	dword ptr [rbx + 40], xmm11     # 4-byte Spill
	vmovss	dword ptr [rbx + 48], xmm6      # 4-byte Spill
	vmovss	dword ptr [rbx + 88], xmm2      # 4-byte Spill
	vmovss	dword ptr [rbx + 172], xmm3     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__check_residual_1839
	mov	qword ptr [rbx + 128], r13
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovss	xmm3, dword ptr [rbx + 172]     # 4-byte Reload
                                        # xmm3 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rbx + 88]      # 4-byte Reload
                                        # xmm2 = mem[0],zero,zero,zero
	vmovss	xmm6, dword ptr [rbx + 48]      # 4-byte Reload
                                        # xmm6 = mem[0],zero,zero,zero
	vmovss	xmm11, dword ptr [rbx + 40]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_28
.LBB0_9:                                #   in Loop: Header=BB0_3 Depth=1
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm11, xmm11, xmm11
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_26
.LBB0_12:                               # %vector.ph1519
                                        #   in Loop: Header=BB0_3 Depth=1
	movabs	rsi, offset .LCPI0_0
	movabs	rax, 9223372036854775792
	vmovaps	ymm0, ymmword ptr [rsi]
	lea	rdx, [rax + 8]
	lea	rax, [r8 + 4*r9]
	xor	esi, esi
	and	rdx, r10
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
.LBB0_13:                               # %vector.body1524
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rax + 4*rsi]
	vmovups	ymm4, ymmword ptr [rcx + 4*rsi]
	add	rsi, 8
	cmp	rdx, rsi
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_13
# %bb.14:                               # %middle.block1516
                                        #   in Loop: Header=BB0_3 Depth=1
	vextractf128	xmm3, ymm2, 1
	mov	r11, qword ptr [rbx + 24]       # 8-byte Reload
	cmp	r10, rdx
	vxorps	xmm10, xmm10, xmm10
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
	vaddss	xmm6, xmm2, xmm3
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm2, xmm1, xmm2
	vaddss	xmm11, xmm0, xmm3
	je	.LBB0_26
.LBB0_15:                               # %scalar.ph1517
                                        #   in Loop: Header=BB0_3 Depth=1
	lea	rax, [r8 + 4*r9]
.LBB0_16:                               # %L81
                                        #   Parent Loop BB0_3 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rax + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm1, dword ptr [rcx + 4*rdx]   # xmm1 = mem[0],zero,zero,zero
	add	rdx, 1
	cmp	r10, rdx
	vfmadd231ss	xmm11, xmm0, xmm0       # xmm11 = (xmm0 * xmm0) + xmm11
	vfmadd231ss	xmm2, xmm1, xmm0        # xmm2 = (xmm1 * xmm0) + xmm2
	vfmadd231ss	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_16
	jmp	.LBB0_26
.LBB0_202:                              # %L1089.loopexit
	mov	rax, qword ptr [rbx + 40]       # 8-byte Reload
	mov	qword ptr [rbx + 192], r14
	mov	qword ptr [rbx + 184], rax
	jmp	.LBB0_203
.LBB0_101:                              # %L1089.loopexit699
	mov	rax, qword ptr [rbx + 136]      # 8-byte Reload
	mov	qword ptr [rbx + 208], r14
	mov	qword ptr [rbx + 200], rax
.LBB0_203:                              # %L1089
	mov	rax, qword ptr [rbx + 104]
	mov	rcx, qword ptr [rbx + 216]      # 8-byte Reload
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
.LBB0_239:                              # %L733.split.us
	movabs	rax, 135794572797712
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 80]
	mov	edx, 1
	mov	qword ptr [rbx + 80], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_230:                              # %L195.split.us
	movabs	rax, 135794572797712
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 80]
	mov	edx, 1
	mov	qword ptr [rbx + 80], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_105:                              # %oob299
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_217
.LBB0_107:                              # %oob299
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_107
.LBB0_217:                              # %oob299
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_246:                              # %L1052
	movabs	rax, offset j__refuse_curvature_1838
	mov	rdi, r14
	vzeroupper
	call	rax
.LBB0_240:                              # %L753
	movabs	rax, offset j_throw_boundserror_1834
	lea	rsi, [rbx + 192]
	mov	qword ptr [rbx + 192], r14
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_172:                              # %oob382
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_222
.LBB0_174:                              # %oob382
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_174
.LBB0_222:                              # %oob382
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_247:                              # %L1071
	movabs	rax, 135794568852048
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 80]
	mov	edx, 1
	mov	qword ptr [rbx + 80], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_4:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_204
.LBB0_6:                                # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_6
.LBB0_204:                              # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_237:                              # %L514
	movabs	rax, offset j__refuse_curvature_1838
	mov	rdi, r14
	vzeroupper
	call	rax
.LBB0_231:                              # %L215
	movabs	rax, offset j_throw_boundserror_1834
	lea	rsi, [rbx + 208]
	mov	qword ptr [rbx + 208], r14
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_71:                               # %oob99
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_209
.LBB0_73:                               # %oob99
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_73
.LBB0_209:                              # %oob99
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_238:                              # %L533
	movabs	rax, 135794568852048
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 80]
	mov	edx, 1
	mov	qword ptr [rbx + 80], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_245:                              # %L989
	movabs	rax, offset j_throw_boundserror_1834
	lea	rsi, [rbx + 184]
	mov	qword ptr [rbx + 184], r14
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_236:                              # %L451
	movabs	rax, offset j_throw_boundserror_1834
	lea	rsi, [rbx + 200]
	mov	qword ptr [rbx + 200], r14
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_241:                              # %L793
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm11
	vzeroupper
	call	rax
.LBB0_232:                              # %L255
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm11
	vzeroupper
	call	rax
.LBB0_218:                              # %oob352
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_221
.LBB0_220:                              # %oob352
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_220
.LBB0_221:                              # %oob352
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r14
	vzeroupper
	call	rax
.LBB0_205:                              # %oob70
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_208
.LBB0_207:                              # %oob70
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_207
.LBB0_208:                              # %oob70
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r14
	vzeroupper
	call	rax
.LBB0_242:                              # %L858
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_243:                              # %L865
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_244:                              # %L872
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_233:                              # %L320
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_234:                              # %L327
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_235:                              # %L334
	movabs	rax, offset j_throw_complex_domainerror_1835
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_184:                              # %oob438
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_223
.LBB0_186:                              # %oob438
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_186
.LBB0_223:                              # %oob438
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_225:                              # %oob448
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_228
.LBB0_227:                              # %oob448
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_227
.LBB0_228:                              # %oob448
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_83:                               # %oob157
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_210
.LBB0_85:                               # %oob157
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_85
.LBB0_210:                              # %oob157
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_212:                              # %oob167
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_215
.LBB0_214:                              # %oob167
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_214
.LBB0_215:                              # %oob167
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	"julia__sweep!_1828", .Lfunc_end0-"julia__sweep!_1828"
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
