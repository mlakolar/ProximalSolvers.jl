	.text
	.file	"_sweep!"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia__sweep!_1804
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
	.globl	"julia__sweep!_1804"
	.p2align	4, 0x90
	.type	"julia__sweep!_1804",@function
"julia__sweep!_1804":                   # @"julia__sweep!_1804"
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	and	rsp, -32
	sub	rsp, 320
	mov	rbx, rsp
	vxorps	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	r15, r9
	mov	qword ptr [rbx + 16], rsi       # 8-byte Spill
	mov	dword ptr [rbx + 164], r8d      # 4-byte Spill
	mov	qword ptr [rbx + 184], rdx      # 8-byte Spill
	vmovaps	ymmword ptr [rbx + 96], ymm0
	mov	qword ptr [rbx + 128], 0
	lea	rsi, [rbx + 96]
	mov	qword ptr [rbx + 8], rdi        # 8-byte Spill
	mov	rdx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 96], 12
	mov	rax, qword ptr [rdx]
	mov	qword ptr [rbx + 104], rax
	mov	qword ptr [rdx], rsi
	test	byte ptr [rcx], 1
	jne	.LBB0_1
# %bb.105:                              # %L529
	mov	rax, qword ptr [r15]
	xor	ecx, ecx
	test	rax, rax
	cmovg	rcx, rax
	mov	qword ptr [rbx + 176], rcx      # 8-byte Spill
	jle	.LBB0_106
# %bb.107:                              # %L545.preheader
	movabs	rax, offset .LCPI0_1
	mov	r11, rdi
	vxorps	xmm10, xmm10, xmm10
	mov	r15d, 1
	xor	r14d, r14d
	mov	qword ptr [rbx + 168], rdx      # 8-byte Spill
	vbroadcastss	ymm0, dword ptr [rax]
	movabs	rax, offset .LCPI0_0
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vmovaps	ymm0, ymmword ptr [rax]
	xor	eax, eax
	mov	qword ptr [rbx + 24], rax       # 8-byte Spill
                                        # implicit-def: $rax
                                        # kill: killed $rax
	vmovaps	ymmword ptr [rbx + 224], ymm0   # 32-byte Spill
	vxorps	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_108:                              # %L545
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_118 Depth 2
                                        #     Child Loop BB0_121 Depth 2
                                        #     Child Loop BB0_127 Depth 2
                                        #     Child Loop BB0_130 Depth 2
                                        #     Child Loop BB0_137 Depth 2
                                        #     Child Loop BB0_157 Depth 2
                                        #     Child Loop BB0_160 Depth 2
                                        #     Child Loop BB0_195 Depth 2
                                        #     Child Loop BB0_198 Depth 2
	mov	rax, qword ptr [rbx + 16]       # 8-byte Reload
	lea	r12, [r15 - 1]
	mov	r13, qword ptr [rax]
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_109
# %bb.112:                              # %idxend283
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovss	dword ptr [rbx + 92], xmm0      # 4-byte Spill
	vmovss	xmm11, dword ptr [rax + 4*r15 - 4] # xmm11 = mem[0],zero,zero,zero
	mov	rax, qword ptr [r13]
	mov	r9, qword ptr [rdi + 8]
	vucomiss	xmm11, xmm11
	jp	.LBB0_113
# %bb.122:                              # %L608
                                        #   in Loop: Header=BB0_108 Depth=1
	test	r9, r9
	je	.LBB0_123
# %bb.124:                              # %L621.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	r10, qword ptr [rax]
	mov	r8, qword ptr [rax + 24]
	mov	rdx, qword ptr [rdi]
	cmp	r9, 16
	jae	.LBB0_126
# %bb.125:                              #   in Loop: Header=BB0_108 Depth=1
	vxorps	xmm2, xmm2, xmm2
	xor	esi, esi
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_129
	.p2align	4, 0x90
.LBB0_123:                              #   in Loop: Header=BB0_108 Depth=1
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_131
	.p2align	4, 0x90
.LBB0_126:                              # %vector.ph1589
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, r9
	movabs	rax, 9223372036854775792
	vmovaps	ymm2, ymmword ptr [rbx + 224]   # 32-byte Reload
	vmovaps	ymm3, ymmword ptr [rbx + 256]   # 32-byte Reload
	xor	ecx, ecx
	and	rsi, rax
	mov	rax, r8
	imul	rax, r14
	vmovaps	ymm0, ymm2
	vmovaps	ymm1, ymm3
	add	rax, r10
	add	rax, 32
	.p2align	4, 0x90
.LBB0_127:                              # %vector.body1594
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm4, ymmword ptr [rdx + 4*rcx]
	vmovups	ymm5, ymmword ptr [rdx + 4*rcx + 32]
	vfmadd231ps	ymm0, ymm4, ymmword ptr [rax + 4*rcx - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rax + 4*rcx] # ymm1 = (ymm5 * mem) + ymm1
	add	rcx, 16
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rsi, rcx
	jne	.LBB0_127
# %bb.128:                              # %middle.block1586
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddps	ymm2, ymm3, ymm2
	vaddps	ymm0, ymm1, ymm0
	cmp	r9, rsi
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
	je	.LBB0_131
.LBB0_129:                              # %scalar.ph1587
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r10, r8
	.p2align	4, 0x90
.LBB0_130:                              # %L621
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rdx + 4*rsi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm2, xmm0, dword ptr [r10 + 4*rsi] # xmm2 = (xmm0 * mem) + xmm2
	add	rsi, 1
	vfmadd231ss	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r9, rsi
	jne	.LBB0_130
.LBB0_131:                              # %L649
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubss	xmm3, xmm6, xmm6
	vucomiss	xmm3, xmm3
	jp	.LBB0_132
.LBB0_133:                              # %L656
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm11, xmm10
	jne	.LBB0_139
	jp	.LBB0_139
# %bb.134:                              # %L658
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_139
# %bb.135:                              # %L671.preheader
                                        #   in Loop: Header=BB0_108 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_221
# %bb.136:                              # %ib329.us.preheader
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, rax
	xor	edx, edx
	imul	rcx, r14
	add	rcx, qword ptr [rdi]
	.p2align	4, 0x90
.LBB0_137:                              # %ib329.us
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm10
	jne	.LBB0_242
	jp	.LBB0_242
# %bb.138:                              # %L677.us
                                        #   in Loop: Header=BB0_137 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_137
.LBB0_139:                              # %L697
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubss	xmm0, xmm11, xmm11
	vucomiss	xmm0, xmm0
	jp	.LBB0_249
# %bb.140:                              # %L702
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_243
# %bb.141:                              # %L716
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_142
# %bb.143:                              # %L721
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	xmm0, dword ptr [rcx + 4*rax - 4] # xmm0 = mem[0],zero,zero,zero
	jmp	.LBB0_144
	.p2align	4, 0x90
.LBB0_142:                              #   in Loop: Header=BB0_108 Depth=1
	vxorps	xmm0, xmm0, xmm0
.LBB0_144:                              # %L726
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm11, xmm10
	vmovss	dword ptr [rbx + 48], xmm0      # 4-byte Spill
	jne	.LBB0_146
	jnp	.LBB0_145
.LBB0_146:                              # %L730
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rbx + 16]       # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vcvtsi2ss	xmm1, xmm13, rax
	vmulss	xmm1, xmm1, dword ptr [rsi]
	vucomiss	xmm11, xmm1
	jb	.LBB0_174
# %bb.147:                              # %L730
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm3, xmm3
	jp	.LBB0_174
# %bb.148:                              # %L730
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm6, xmm1
	jb	.LBB0_174
# %bb.149:                              # %L749
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm10, xmm11
	ja	.LBB0_244
# %bb.150:                              # %L755
                                        #   in Loop: Header=BB0_108 Depth=1
	vsqrtss	xmm5, xmm11, xmm11
	mov	rsi, qword ptr [rbx + 16]       # 8-byte Reload
	vxorps	xmm0, xmm0, xmm0
	vmovss	xmm4, dword ptr [rsi + 8]       # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm5
	jae	.LBB0_175
# %bb.151:                              # %L760
                                        #   in Loop: Header=BB0_108 Depth=1
	vdivss	xmm3, xmm2, xmm11
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm0, xmm2, xmm3
	vmulss	xmm2, xmm6, dword ptr [rsi]
	vsubss	xmm0, xmm6, xmm0
	vucomiss	xmm2, xmm0
	jbe	.LBB0_164
# %bb.152:                              # %L767
                                        #   in Loop: Header=BB0_108 Depth=1
	test	rax, rax
	je	.LBB0_153
# %bb.154:                              # %L781.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	cmp	rax, 16
	mov	r9, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	jae	.LBB0_156
# %bb.155:                              #   in Loop: Header=BB0_108 Depth=1
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_159
	.p2align	4, 0x90
.LBB0_145:                              # %L728
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 184]      # 8-byte Reload
	mov	rsi, r15
	movabs	rax, offset j__coordinate_minimizer_1808
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 32], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 32]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_175
	.p2align	4, 0x90
.LBB0_174:                              # %L927
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	mov	rsi, r15
	movabs	rax, offset j__sqrt_offrange_step_1813
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 32], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 32]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
.LBB0_175:                              # %L930
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_176
# %bb.179:                              # %idxend366
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubss	xmm1, xmm0, dword ptr [rbx + 48] # 4-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovss	dword ptr [rax + 4*r15 - 4], xmm11
	vucomiss	xmm1, xmm10
	jne	.LBB0_180
	jnp	.LBB0_200
.LBB0_180:                              # %L938
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_248
# %bb.181:                              # %L952
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_186
# %bb.182:                              # %L957
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	dword ptr [rcx + 4*rax - 4], xmm0
	jmp	.LBB0_183
	.p2align	4, 0x90
.LBB0_186:                              # %L960
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm0, xmm10
	jne	.LBB0_187
	jnp	.LBB0_183
.LBB0_187:                              # %L963
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdx, qword ptr [r11 + 24]
	lea	rax, [rdx + 1]
	mov	qword ptr [r11 + 24], rax
	mov	rdi, qword ptr [r11]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_188
# %bb.227:                              # %idxend422
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovss	dword ptr [rsi + 4*rdx], xmm0
	mov	rdi, qword ptr [r11 + 8]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_228
# %bb.232:                              # %idxend442
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rdx], r15
	mov	qword ptr [rcx + 8*r15 - 8], rax
	.p2align	4, 0x90
.LBB0_183:                              # %L977
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 64], r15       # 8-byte Spill
	mov	r9, qword ptr [rax + 8]
	test	r9, r9
	je	.LBB0_200
# %bb.184:                              # %L990.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, qword ptr [r13]
	mov	rcx, qword ptr [rax]
	cmp	r9, 32
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	jae	.LBB0_191
# %bb.185:                              #   in Loop: Header=BB0_108 Depth=1
	xor	edi, edi
	jmp	.LBB0_197
.LBB0_191:                              # %vector.memcheck1525
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rbx + 24]       # 8-byte Reload
	lea	rax, [4*rax]
	imul	rax, r8
	add	rax, rdx
	lea	rsi, [rax + 4*r9]
	cmp	rsi, rcx
	jbe	.LBB0_194
# %bb.192:                              # %vector.memcheck1525
                                        #   in Loop: Header=BB0_108 Depth=1
	lea	rsi, [rcx + 4*r9]
	cmp	rax, rsi
	jae	.LBB0_194
# %bb.193:                              #   in Loop: Header=BB0_108 Depth=1
	xor	edi, edi
	jmp	.LBB0_197
.LBB0_194:                              # %vector.ph1539
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, 9223372036854775792
	vbroadcastss	ymm0, xmm1
	lea	rdi, [rax - 16]
	mov	rax, r8
	imul	rax, r14
	and	rdi, r9
	lea	rsi, [rdx + rax + 96]
	xor	eax, eax
	.p2align	4, 0x90
.LBB0_195:                              # %vector.body1544
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm3, ymm0, ymmword ptr [rsi + 4*rax - 64]
	vmulps	ymm2, ymm0, ymmword ptr [rsi + 4*rax - 96]
	vmulps	ymm4, ymm0, ymmword ptr [rsi + 4*rax - 32]
	vmulps	ymm5, ymm0, ymmword ptr [rsi + 4*rax]
	vmovups	ymm7, ymmword ptr [rcx + 4*rax + 32]
	vmovups	ymm6, ymmword ptr [rcx + 4*rax]
	vmovups	ymm8, ymmword ptr [rcx + 4*rax + 64]
	vsubps	ymm3, ymm7, ymm3
	vmovups	ymm7, ymmword ptr [rcx + 4*rax + 96]
	vsubps	ymm2, ymm6, ymm2
	vsubps	ymm4, ymm8, ymm4
	vsubps	ymm5, ymm7, ymm5
	vmovups	ymmword ptr [rcx + 4*rax], ymm2
	vmovups	ymmword ptr [rcx + 4*rax + 32], ymm3
	vmovups	ymmword ptr [rcx + 4*rax + 64], ymm4
	vmovups	ymmword ptr [rcx + 4*rax + 96], ymm5
	add	rax, 32
	cmp	rdi, rax
	jne	.LBB0_195
# %bb.196:                              # %middle.block1536
                                        #   in Loop: Header=BB0_108 Depth=1
	cmp	r9, rdi
	mov	qword ptr [rbx + 64], r15       # 8-byte Spill
	je	.LBB0_200
	.p2align	4, 0x90
.LBB0_197:                              # %scalar.ph1537
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_198:                              # %L990
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm0, xmm1, dword ptr [rdx + 4*rdi]
	vmovss	xmm2, dword ptr [rcx + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm0, xmm2, xmm0
	vmovss	dword ptr [rcx + 4*rdi], xmm0
	add	rdi, 1
	cmp	r9, rdi
	jne	.LBB0_198
# %bb.199:                              #   in Loop: Header=BB0_108 Depth=1
	mov	qword ptr [rbx + 64], r15       # 8-byte Spill
.LBB0_200:                              # %L1014
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, offset .LCPI0_6
	test	byte ptr [rbx + 164], 1         # 1-byte Folded Reload
	vbroadcastss	xmm0, dword ptr [rax]
	vandps	xmm2, xmm1, xmm0
	je	.LBB0_203
# %bb.201:                              # %L1014
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm1, xmm10
	jne	.LBB0_202
	jnp	.LBB0_203
.LBB0_202:                              # %L1020
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rax, qword ptr [rbx + 16]       # 8-byte Reload
	mov	rsi, r11
	mov	rdx, r15
	vmovaps	xmmword ptr [rbx + 48], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_1809
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovaps	xmm2, xmmword ptr [rbx + 48]    # 16-byte Reload
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	vmulss	xmm2, xmm2, xmm0
.LBB0_203:                              # %L1025
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubss	xmm0, xmm2, xmm2
	vucomiss	xmm0, xmm0
	jp	.LBB0_250
# %bb.204:                              # %L1034
                                        #   in Loop: Header=BB0_108 Depth=1
	vmovss	xmm0, dword ptr [rbx + 92]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	add	qword ptr [rbx + 24], 1         # 8-byte Folded Spill
	add	r14, 4
	cmp	r15, qword ptr [rbx + 176]      # 8-byte Folded Reload
	lea	r15, [r15 + 1]
	vmaxss	xmm0, xmm2, xmm0
	jne	.LBB0_108
	jmp	.LBB0_205
.LBB0_153:                              #   in Loop: Header=BB0_108 Depth=1
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_161
.LBB0_156:                              # %vector.ph1566
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, rax
	movabs	rdx, 9223372036854775792
	vbroadcastss	ymm2, xmm3
	and	rsi, rdx
	movabs	rdx, offset .LCPI0_1
	vbroadcastss	ymm0, dword ptr [rdx]
	mov	rdx, r8
	imul	rdx, r14
	lea	rdi, [r9 + rdx + 32]
	movabs	rdx, offset .LCPI0_0
	vmovaps	ymm6, ymmword ptr [rdx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_157:                              # %vector.body1571
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm7, ymm2, ymmword ptr [rdi + 4*rdx - 32]
	vmulps	ymm8, ymm2, ymmword ptr [rdi + 4*rdx]
	vmovups	ymm9, ymmword ptr [rcx + 4*rdx]
	vmovups	ymm12, ymmword ptr [rcx + 4*rdx + 32]
	add	rdx, 16
	cmp	rsi, rdx
	vsubps	ymm7, ymm9, ymm7
	vsubps	ymm8, ymm12, ymm8
	vfmadd231ps	ymm6, ymm7, ymm7        # ymm6 = (ymm7 * ymm7) + ymm6
	vfmadd231ps	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	jne	.LBB0_157
# %bb.158:                              # %middle.block1563
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddps	ymm0, ymm0, ymm6
	cmp	rax, rsi
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm2
	je	.LBB0_161
.LBB0_159:                              # %scalar.ph1564
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r9, r8
	.p2align	4, 0x90
.LBB0_160:                              # %L781
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm2, xmm3, dword ptr [r9 + 4*rsi]
	vmovss	xmm6, dword ptr [rcx + 4*rsi]   # xmm6 = mem[0],zero,zero,zero
	add	rsi, 1
	cmp	rax, rsi
	vsubss	xmm2, xmm6, xmm2
	vfmadd231ss	xmm0, xmm2, xmm2        # xmm0 = (xmm2 * xmm2) + xmm0
	jne	.LBB0_160
.LBB0_161:                              # %L804
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm0, xmm1
	jb	.LBB0_163
# %bb.162:                              # %L804
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubss	xmm1, xmm0, xmm0
	vucomiss	xmm1, xmm1
	jp	.LBB0_163
.LBB0_164:                              # %L815
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm10, xmm0
	ja	.LBB0_245
# %bb.165:                              # %L820
                                        #   in Loop: Header=BB0_108 Depth=1
	vsubss	xmm1, xmm5, xmm4
	vucomiss	xmm10, xmm1
	ja	.LBB0_246
# %bb.166:                              # %L827
                                        #   in Loop: Header=BB0_108 Depth=1
	vaddss	xmm2, xmm5, xmm4
	vucomiss	xmm10, xmm2
	ja	.LBB0_247
# %bb.167:                              # %L834
                                        #   in Loop: Header=BB0_108 Depth=1
	vsqrtss	xmm1, xmm1, xmm1
	vsqrtss	xmm2, xmm2, xmm2
	movabs	rax, offset .LCPI0_4
	vmulss	xmm1, xmm1, xmm2
	vmulss	xmm1, xmm5, xmm1
	vucomiss	xmm1, dword ptr [rax]
	jb	.LBB0_173
# %bb.168:                              # %L834
                                        #   in Loop: Header=BB0_108 Depth=1
	vsqrtss	xmm0, xmm0, xmm0
	movabs	rax, offset .LCPI0_4
	vdivss	xmm0, xmm0, xmm1
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_173
# %bb.169:                              # %L834
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, offset .LCPI0_5
	vmovss	xmm1, dword ptr [rax]           # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm0
	jb	.LBB0_173
# %bb.170:                              # %L834
                                        #   in Loop: Header=BB0_108 Depth=1
	vmulss	xmm0, xmm4, xmm0
	movabs	rax, offset .LCPI0_4
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_173
# %bb.171:                              # %L834
                                        #   in Loop: Header=BB0_108 Depth=1
	vucomiss	xmm1, xmm0
	jb	.LBB0_173
# %bb.172:                              # %L868
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, offset .LCPI0_1
	vaddss	xmm2, xmm3, dword ptr [rbx + 48] # 4-byte Folded Reload
	vbroadcastss	xmm1, dword ptr [rax]
	vxorps	xmm1, xmm0, xmm1
	vmaxss	xmm1, xmm2, xmm1
	vminss	xmm0, xmm1, xmm0
	vsubss	xmm0, xmm2, xmm0
	vaddss	xmm0, xmm10, xmm0
	jmp	.LBB0_175
.LBB0_173:                              # %L925
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 48]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r15
	movabs	rax, offset j__sqrt_offrange_step_1813
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 32], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 32]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_175
.LBB0_163:                              # %L813
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 48]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r15
	movabs	rax, offset j__sqrt_offrange_step_1813
	mov	qword ptr [rbx + 120], r13
	vmovss	dword ptr [rbx + 32], xmm11     # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 32]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_175
.LBB0_113:                              # %L565
                                        #   in Loop: Header=BB0_108 Depth=1
	test	r9, r9
	je	.LBB0_114
# %bb.115:                              # %L579.lr.ph
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	r10, qword ptr [rax]
	mov	r8, qword ptr [rax + 24]
	mov	rdx, qword ptr [rdi]
	cmp	r9, 8
	jae	.LBB0_117
# %bb.116:                              #   in Loop: Header=BB0_108 Depth=1
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm11, xmm11, xmm11
	xor	esi, esi
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_120
.LBB0_132:                              # %L654
                                        #   in Loop: Header=BB0_108 Depth=1
	mov	rsi, r15
	movabs	rax, offset j__check_residual_1815
	mov	qword ptr [rbx + 120], r13
	mov	qword ptr [rbx + 112], rdi
	vmovss	dword ptr [rbx + 32], xmm11     # 4-byte Spill
	vmovss	dword ptr [rbx + 48], xmm6      # 4-byte Spill
	vmovss	dword ptr [rbx + 88], xmm2      # 4-byte Spill
	vmovss	dword ptr [rbx + 84], xmm3      # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm3, dword ptr [rbx + 84]      # 4-byte Reload
                                        # xmm3 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rbx + 88]      # 4-byte Reload
                                        # xmm2 = mem[0],zero,zero,zero
	vmovss	xmm6, dword ptr [rbx + 48]      # 4-byte Reload
                                        # xmm6 = mem[0],zero,zero,zero
	vmovss	xmm11, dword ptr [rbx + 32]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_133
.LBB0_114:                              #   in Loop: Header=BB0_108 Depth=1
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm11, xmm11, xmm11
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_131
.LBB0_117:                              # %vector.ph1612
                                        #   in Loop: Header=BB0_108 Depth=1
	movabs	rax, 9223372036854775792
	movabs	rcx, offset .LCPI0_0
	lea	rsi, [rax + 8]
	mov	rax, r8
	vmovaps	ymm0, ymmword ptr [rcx]
	xor	ecx, ecx
	imul	rax, r14
	and	rsi, r9
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	add	rax, r10
.LBB0_118:                              # %vector.body1617
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rax + 4*rcx]
	vmovups	ymm4, ymmword ptr [rdx + 4*rcx]
	add	rcx, 8
	cmp	rsi, rcx
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_118
# %bb.119:                              # %middle.block1609
                                        #   in Loop: Header=BB0_108 Depth=1
	vextractf128	xmm3, ymm2, 1
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	cmp	r9, rsi
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
	je	.LBB0_131
.LBB0_120:                              # %scalar.ph1610
                                        #   in Loop: Header=BB0_108 Depth=1
	imul	r8, r14
	add	r10, r8
.LBB0_121:                              # %L579
                                        #   Parent Loop BB0_108 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [r10 + 4*rsi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm1, dword ptr [rdx + 4*rsi]   # xmm1 = mem[0],zero,zero,zero
	add	rsi, 1
	cmp	r9, rsi
	vfmadd231ss	xmm11, xmm0, xmm0       # xmm11 = (xmm0 * xmm0) + xmm11
	vfmadd231ss	xmm2, xmm1, xmm0        # xmm2 = (xmm1 * xmm0) + xmm2
	vfmadd231ss	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_121
	jmp	.LBB0_131
.LBB0_1:                                # %L4
	mov	r14, qword ptr [r15]
	mov	rdi, qword ptr [rcx + 8]
	movabs	rax, offset "j__shuffle!_1806"
	mov	qword ptr [rbx + 168], rdx      # 8-byte Spill
	mov	rsi, r14
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	test	r14, r14
	mov	qword ptr [rbx + 48], rax       # 8-byte Spill
	jle	.LBB0_2
# %bb.3:                                # %L4
	mov	rax, qword ptr [r15]
	jmp	.LBB0_4
.LBB0_205:                              # %L1049.loopexit
	mov	rax, qword ptr [rbx + 176]      # 8-byte Reload
	mov	rcx, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdx, qword ptr [rbx + 168]      # 8-byte Reload
	mov	qword ptr [rbx + 200], rax
	mov	qword ptr [rbx + 192], rcx
	jmp	.LBB0_206
.LBB0_2:
	xor	eax, eax
.LBB0_4:                                # %L4
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	test	rax, rax
	jle	.LBB0_5
# %bb.6:                                # %L22.preheader
	movabs	rcx, offset .LCPI0_1
	vxorps	xmm10, xmm10, xmm10
	mov	r14d, 1
	mov	qword ptr [rbx + 176], rax      # 8-byte Spill
	vbroadcastss	ymm0, dword ptr [rcx]
	movabs	rcx, offset .LCPI0_0
	vmovaps	ymmword ptr [rbx + 256], ymm0   # 32-byte Spill
	vmovaps	ymm0, ymmword ptr [rcx]
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
	vmovaps	ymmword ptr [rbx + 224], ymm0   # 32-byte Spill
	vxorps	xmm0, xmm0, xmm0
	.p2align	4, 0x90
.LBB0_7:                                # %L22
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_17 Depth 2
                                        #     Child Loop BB0_20 Depth 2
                                        #     Child Loop BB0_26 Depth 2
                                        #     Child Loop BB0_29 Depth 2
                                        #     Child Loop BB0_36 Depth 2
                                        #     Child Loop BB0_56 Depth 2
                                        #     Child Loop BB0_59 Depth 2
                                        #     Child Loop BB0_94 Depth 2
                                        #     Child Loop BB0_97 Depth 2
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 16]       # 8-byte Reload
	mov	rax, qword ptr [rax]
	mov	r13, qword ptr [rcx]
	mov	r15, qword ptr [rax + 8*r14 - 8]
	mov	rdi, qword ptr [r13 + 32]
	lea	r12, [r15 - 1]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_8
# %bb.11:                               # %idxend
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rdi, qword ptr [r13 + 24]
	vmovss	dword ptr [rbx + 92], xmm0      # 4-byte Spill
	vmovss	xmm11, dword ptr [rax + 4*r15 - 4] # xmm11 = mem[0],zero,zero,zero
	mov	rax, qword ptr [r13]
	mov	r10, qword ptr [rdi + 8]
	vucomiss	xmm11, xmm11
	jp	.LBB0_12
# %bb.21:                               # %L86
                                        #   in Loop: Header=BB0_7 Depth=1
	test	r10, r10
	je	.LBB0_22
# %bb.23:                               # %L99.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r10, 16
	jae	.LBB0_25
# %bb.24:                               #   in Loop: Header=BB0_7 Depth=1
	vxorps	xmm2, xmm2, xmm2
	xor	edx, edx
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_28
	.p2align	4, 0x90
.LBB0_22:                               #   in Loop: Header=BB0_7 Depth=1
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_30
	.p2align	4, 0x90
.LBB0_25:                               # %vector.ph1486
                                        #   in Loop: Header=BB0_7 Depth=1
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
.LBB0_26:                               # %vector.body1491
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm4, ymmword ptr [rcx + 4*rax]
	vmovups	ymm5, ymmword ptr [rcx + 4*rax + 32]
	vfmadd231ps	ymm0, ymm4, ymmword ptr [rsi + 4*rax - 32] # ymm0 = (ymm4 * mem) + ymm0
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rsi + 4*rax] # ymm1 = (ymm5 * mem) + ymm1
	add	rax, 16
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	cmp	rdx, rax
	jne	.LBB0_26
# %bb.27:                               # %middle.block1483
                                        #   in Loop: Header=BB0_7 Depth=1
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
	je	.LBB0_30
.LBB0_28:                               # %scalar.ph1484
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rax, [r8 + 4*r9]
	.p2align	4, 0x90
.LBB0_29:                               # %L99
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm2, xmm0, dword ptr [rax + 4*rdx] # xmm2 = (xmm0 * mem) + xmm2
	add	rdx, 1
	vfmadd231ss	xmm6, xmm0, xmm0        # xmm6 = (xmm0 * xmm0) + xmm6
	cmp	r10, rdx
	jne	.LBB0_29
.LBB0_30:                               # %L127
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubss	xmm3, xmm6, xmm6
	vucomiss	xmm3, xmm3
	jp	.LBB0_31
.LBB0_32:                               # %L134
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm11, xmm10
	jne	.LBB0_38
	jp	.LBB0_38
# %bb.33:                               # %L136
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r13]
	mov	rax, qword ptr [rdi + 24]
	test	rax, rax
	je	.LBB0_38
# %bb.34:                               # %L149.preheader
                                        #   in Loop: Header=BB0_7 Depth=1
	cmp	r12, qword ptr [rdi + 32]
	jae	.LBB0_208
# %bb.35:                               # %ib.us.preheader
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, rax
	mov	rdx, qword ptr [rdi]
	imul	rcx, r12
	lea	rcx, [rdx + 4*rcx]
	xor	edx, edx
	.p2align	4, 0x90
.LBB0_36:                               # %ib.us
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rcx + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm10
	jne	.LBB0_233
	jp	.LBB0_233
# %bb.37:                               # %L155.us
                                        #   in Loop: Header=BB0_36 Depth=2
	add	rdx, 1
	cmp	rdx, rax
	jb	.LBB0_36
.LBB0_38:                               # %L175
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubss	xmm0, xmm11, xmm11
	vucomiss	xmm0, xmm0
	jp	.LBB0_240
# %bb.39:                               # %L180
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_234
# %bb.40:                               # %L194
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rdi]
	mov	rax, qword ptr [rax + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_41
# %bb.42:                               # %L199
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	xmm0, dword ptr [rcx + 4*rax - 4] # xmm0 = mem[0],zero,zero,zero
	jmp	.LBB0_43
	.p2align	4, 0x90
.LBB0_41:                               #   in Loop: Header=BB0_7 Depth=1
	vxorps	xmm0, xmm0, xmm0
.LBB0_43:                               # %L204
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm11, xmm10
	vmovss	dword ptr [rbx + 32], xmm0      # 4-byte Spill
	jne	.LBB0_45
	jnp	.LBB0_44
.LBB0_45:                               # %L208
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 16]       # 8-byte Reload
	movabs	rsi, offset .LCPI0_2
	mov	rcx, qword ptr [rax]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vcvtsi2ss	xmm1, xmm13, rax
	vmulss	xmm1, xmm1, dword ptr [rsi]
	vucomiss	xmm11, xmm1
	jb	.LBB0_73
# %bb.46:                               # %L208
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm3, xmm3
	jp	.LBB0_73
# %bb.47:                               # %L208
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm6, xmm1
	jb	.LBB0_73
# %bb.48:                               # %L227
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm10, xmm11
	ja	.LBB0_235
# %bb.49:                               # %L233
                                        #   in Loop: Header=BB0_7 Depth=1
	vsqrtss	xmm5, xmm11, xmm11
	mov	rsi, qword ptr [rbx + 16]       # 8-byte Reload
	vxorps	xmm0, xmm0, xmm0
	vmovss	xmm4, dword ptr [rsi + 8]       # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm5
	jae	.LBB0_74
# %bb.50:                               # %L238
                                        #   in Loop: Header=BB0_7 Depth=1
	vdivss	xmm3, xmm2, xmm11
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm0, xmm2, xmm3
	vmulss	xmm2, xmm6, dword ptr [rsi]
	vsubss	xmm0, xmm6, xmm0
	vucomiss	xmm2, xmm0
	jbe	.LBB0_63
# %bb.51:                               # %L245
                                        #   in Loop: Header=BB0_7 Depth=1
	test	rax, rax
	je	.LBB0_52
# %bb.53:                               # %L259.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	r9, qword ptr [rsi + 24]
	mov	r8, qword ptr [rsi]
	imul	r9, r12
	cmp	rax, 16
	jae	.LBB0_55
# %bb.54:                               #   in Loop: Header=BB0_7 Depth=1
	vxorps	xmm0, xmm0, xmm0
	xor	edx, edx
	jmp	.LBB0_58
	.p2align	4, 0x90
.LBB0_44:                               # %L206
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 184]      # 8-byte Reload
	mov	rsi, r15
	vmovss	dword ptr [rbx + 24], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__coordinate_minimizer_1808
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 24]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_74
	.p2align	4, 0x90
.LBB0_73:                               # %L405
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	mov	rsi, r15
	vmovss	dword ptr [rbx + 24], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_1813
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 24]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
.LBB0_74:                               # %L408
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r13 + 32]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_75
# %bb.78:                               # %idxend91
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubss	xmm1, xmm0, dword ptr [rbx + 32] # 4-byte Folded Reload
	mov	rax, qword ptr [rdi]
	vmovss	dword ptr [rax + 4*r15 - 4], xmm11
	vucomiss	xmm1, xmm10
	jne	.LBB0_79
	jnp	.LBB0_99
.LBB0_79:                               # %L416
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdi, qword ptr [r11 + 16]
	cmp	r12, qword ptr [rdi + 8]
	jae	.LBB0_239
# %bb.80:                               # %L430
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [rdi]
	mov	rax, qword ptr [rcx + 8*r15 - 8]
	test	rax, rax
	je	.LBB0_85
# %bb.81:                               # %L435
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [r11]
	mov	rcx, qword ptr [rcx]
	vmovss	dword ptr [rcx + 4*rax - 4], xmm0
	jmp	.LBB0_82
	.p2align	4, 0x90
.LBB0_85:                               # %L438
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm0, xmm10
	jne	.LBB0_86
	jnp	.LBB0_82
.LBB0_86:                               # %L441
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdx, qword ptr [r11 + 24]
	lea	rax, [rdx + 1]
	mov	qword ptr [r11 + 24], rax
	mov	rdi, qword ptr [r11]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_87
# %bb.214:                              # %idxend149
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, qword ptr [rdi]
	vmovss	dword ptr [rsi + 4*rdx], xmm0
	mov	rdi, qword ptr [r11 + 8]
	cmp	rdx, qword ptr [rdi + 8]
	jae	.LBB0_215
# %bb.219:                              # %idxend169
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rsi, qword ptr [rdi]
	mov	qword ptr [rsi + 8*rdx], r15
	mov	qword ptr [rcx + 8*r15 - 8], rax
	.p2align	4, 0x90
.LBB0_82:                               # %L455
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rcx, qword ptr [r13 + 24]
	mov	qword ptr [rbx + 64], r15       # 8-byte Spill
	mov	rax, qword ptr [rcx + 8]
	test	rax, rax
	je	.LBB0_99
# %bb.83:                               # %L468.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rdx, qword ptr [r13]
	mov	rcx, qword ptr [rcx]
	imul	r12, qword ptr [rdx + 24]
	mov	r8, qword ptr [rdx]
	cmp	rax, 32
	jae	.LBB0_90
# %bb.84:                               #   in Loop: Header=BB0_7 Depth=1
	xor	esi, esi
	jmp	.LBB0_96
.LBB0_90:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rdx, [rax + r12]
	lea	rdx, [r8 + 4*rdx]
	cmp	rcx, rdx
	jae	.LBB0_93
# %bb.91:                               # %vector.memcheck
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rdx, [rcx + 4*rax]
	lea	rsi, [r8 + 4*r12]
	cmp	rsi, rdx
	jae	.LBB0_93
# %bb.92:                               #   in Loop: Header=BB0_7 Depth=1
	xor	esi, esi
	jmp	.LBB0_96
.LBB0_93:                               # %vector.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rdx, 9223372036854775792
	vbroadcastss	ymm0, xmm1
	lea	rdi, [r8 + 4*r12 + 96]
	lea	rsi, [rdx - 16]
	xor	edx, edx
	and	rsi, rax
	.p2align	4, 0x90
.LBB0_94:                               # %vector.body
                                        #   Parent Loop BB0_7 Depth=1
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
	jne	.LBB0_94
# %bb.95:                               # %middle.block
                                        #   in Loop: Header=BB0_7 Depth=1
	cmp	rax, rsi
	mov	qword ptr [rbx + 64], r15       # 8-byte Spill
	je	.LBB0_99
	.p2align	4, 0x90
.LBB0_96:                               # %scalar.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rdx, [r8 + 4*r12]
	.p2align	4, 0x90
.LBB0_97:                               # %L468
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm0, xmm1, dword ptr [rdx + 4*rsi]
	vmovss	xmm2, dword ptr [rcx + 4*rsi]   # xmm2 = mem[0],zero,zero,zero
	vsubss	xmm0, xmm2, xmm0
	vmovss	dword ptr [rcx + 4*rsi], xmm0
	add	rsi, 1
	cmp	rax, rsi
	jne	.LBB0_97
# %bb.98:                               #   in Loop: Header=BB0_7 Depth=1
	mov	qword ptr [rbx + 64], r15       # 8-byte Spill
.LBB0_99:                               # %L492
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rax, offset .LCPI0_6
	test	byte ptr [rbx + 164], 1         # 1-byte Folded Reload
	vbroadcastss	xmm0, dword ptr [rax]
	vandps	xmm2, xmm1, xmm0
	je	.LBB0_102
# %bb.100:                              # %L492
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm1, xmm10
	jne	.LBB0_101
	jnp	.LBB0_102
.LBB0_101:                              # %L498
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 16]       # 8-byte Reload
	mov	rcx, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rsi, r11
	mov	rdx, r15
	vmovaps	xmmword ptr [rbx + 32], xmm2    # 16-byte Spill
	mov	rdi, qword ptr [rax]
	movabs	rax, offset j_coordinate_scale_1809
	mov	qword ptr [rbx + 120], rcx
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovaps	xmm2, xmmword ptr [rbx + 32]    # 16-byte Reload
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	vmulss	xmm2, xmm2, xmm0
.LBB0_102:                              # %L503
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubss	xmm0, xmm2, xmm2
	mov	rax, qword ptr [rbx + 176]      # 8-byte Reload
	vucomiss	xmm0, xmm0
	jp	.LBB0_241
# %bb.103:                              # %L512
                                        #   in Loop: Header=BB0_7 Depth=1
	vmovss	xmm0, dword ptr [rbx + 92]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	cmp	r14, rax
	lea	r14, [r14 + 1]
	vmaxss	xmm0, xmm2, xmm0
	jne	.LBB0_7
	jmp	.LBB0_104
.LBB0_52:                               #   in Loop: Header=BB0_7 Depth=1
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_60
.LBB0_55:                               # %vector.ph1466
                                        #   in Loop: Header=BB0_7 Depth=1
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
.LBB0_56:                               # %vector.body1471
                                        #   Parent Loop BB0_7 Depth=1
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
	jne	.LBB0_56
# %bb.57:                               # %middle.block1463
                                        #   in Loop: Header=BB0_7 Depth=1
	vaddps	ymm0, ymm0, ymm2
	cmp	rax, rdx
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm2
	je	.LBB0_60
.LBB0_58:                               # %scalar.ph1464
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rsi, [r8 + 4*r9]
	.p2align	4, 0x90
.LBB0_59:                               # %L259
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulss	xmm2, xmm3, dword ptr [rsi + 4*rdx]
	vmovss	xmm6, dword ptr [rcx + 4*rdx]   # xmm6 = mem[0],zero,zero,zero
	add	rdx, 1
	cmp	rax, rdx
	vsubss	xmm2, xmm6, xmm2
	vfmadd231ss	xmm0, xmm2, xmm2        # xmm0 = (xmm2 * xmm2) + xmm0
	jne	.LBB0_59
.LBB0_60:                               # %L282
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm0, xmm1
	jb	.LBB0_62
# %bb.61:                               # %L282
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubss	xmm1, xmm0, xmm0
	vucomiss	xmm1, xmm1
	jp	.LBB0_62
.LBB0_63:                               # %L293
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm10, xmm0
	ja	.LBB0_236
# %bb.64:                               # %L298
                                        #   in Loop: Header=BB0_7 Depth=1
	vsubss	xmm1, xmm5, xmm4
	movabs	rax, offset .LCPI0_4
	vucomiss	xmm10, xmm1
	ja	.LBB0_237
# %bb.65:                               # %L305
                                        #   in Loop: Header=BB0_7 Depth=1
	vaddss	xmm2, xmm5, xmm4
	vucomiss	xmm10, xmm2
	ja	.LBB0_238
# %bb.66:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vsqrtss	xmm1, xmm1, xmm1
	vsqrtss	xmm2, xmm2, xmm2
	vmulss	xmm1, xmm1, xmm2
	vmulss	xmm1, xmm5, xmm1
	vucomiss	xmm1, dword ptr [rax]
	jb	.LBB0_72
# %bb.67:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vsqrtss	xmm0, xmm0, xmm0
	vdivss	xmm0, xmm0, xmm1
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_72
# %bb.68:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rcx, offset .LCPI0_5
	vmovss	xmm1, dword ptr [rcx]           # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm0
	jb	.LBB0_72
# %bb.69:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vmulss	xmm0, xmm4, xmm0
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_72
# %bb.70:                               # %L312
                                        #   in Loop: Header=BB0_7 Depth=1
	vucomiss	xmm1, xmm0
	jb	.LBB0_72
# %bb.71:                               # %L346
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rax, offset .LCPI0_1
	vaddss	xmm2, xmm3, dword ptr [rbx + 32] # 4-byte Folded Reload
	vbroadcastss	xmm1, dword ptr [rax]
	vxorps	xmm1, xmm0, xmm1
	vmaxss	xmm1, xmm2, xmm1
	vminss	xmm0, xmm1, xmm0
	vsubss	xmm0, xmm2, xmm0
	vaddss	xmm0, xmm10, xmm0
	jmp	.LBB0_74
.LBB0_72:                               # %L403
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 32]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r15
	vmovss	dword ptr [rbx + 24], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_1813
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 24]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_74
.LBB0_62:                               # %L291
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rdi, qword ptr [rbx + 16]       # 8-byte Reload
	vmovss	xmm0, dword ptr [rbx + 32]      # 4-byte Reload
                                        # xmm0 = mem[0],zero,zero,zero
	mov	rsi, r15
	vmovss	dword ptr [rbx + 24], xmm11     # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__sqrt_offrange_step_1813
	mov	qword ptr [rbx + 128], r13
	vzeroupper
	call	rax
	vmovss	xmm11, dword ptr [rbx + 24]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_74
.LBB0_12:                               # %L43
                                        #   in Loop: Header=BB0_7 Depth=1
	test	r10, r10
	je	.LBB0_13
# %bb.14:                               # %L57.lr.ph
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	r9, qword ptr [rax + 24]
	mov	r8, qword ptr [rax]
	mov	rcx, qword ptr [rdi]
	imul	r9, r12
	cmp	r10, 8
	jae	.LBB0_16
# %bb.15:                               #   in Loop: Header=BB0_7 Depth=1
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm11, xmm11, xmm11
	xor	edx, edx
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_19
.LBB0_31:                               # %L132
                                        #   in Loop: Header=BB0_7 Depth=1
	mov	rax, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rsi, r15
	vmovss	dword ptr [rbx + 24], xmm11     # 4-byte Spill
	vmovss	dword ptr [rbx + 32], xmm6      # 4-byte Spill
	vmovss	dword ptr [rbx + 88], xmm2      # 4-byte Spill
	vmovss	dword ptr [rbx + 84], xmm3      # 4-byte Spill
	mov	qword ptr [rbx + 120], rax
	movabs	rax, offset j__check_residual_1815
	mov	qword ptr [rbx + 128], r13
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
	vmovss	xmm3, dword ptr [rbx + 84]      # 4-byte Reload
                                        # xmm3 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rbx + 88]      # 4-byte Reload
                                        # xmm2 = mem[0],zero,zero,zero
	vmovss	xmm6, dword ptr [rbx + 32]      # 4-byte Reload
                                        # xmm6 = mem[0],zero,zero,zero
	vmovss	xmm11, dword ptr [rbx + 24]     # 4-byte Reload
                                        # xmm11 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_32
.LBB0_13:                               #   in Loop: Header=BB0_7 Depth=1
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm11, xmm11, xmm11
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_30
.LBB0_16:                               # %vector.ph1509
                                        #   in Loop: Header=BB0_7 Depth=1
	movabs	rsi, offset .LCPI0_0
	movabs	rax, 9223372036854775792
	vmovaps	ymm0, ymmword ptr [rsi]
	lea	rdx, [rax + 8]
	lea	rax, [r8 + 4*r9]
	xor	esi, esi
	and	rdx, r10
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
.LBB0_17:                               # %vector.body1514
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rax + 4*rsi]
	vmovups	ymm4, ymmword ptr [rcx + 4*rsi]
	add	rsi, 8
	cmp	rdx, rsi
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_17
# %bb.18:                               # %middle.block1506
                                        #   in Loop: Header=BB0_7 Depth=1
	vextractf128	xmm3, ymm2, 1
	mov	r11, qword ptr [rbx + 8]        # 8-byte Reload
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
	je	.LBB0_30
.LBB0_19:                               # %scalar.ph1507
                                        #   in Loop: Header=BB0_7 Depth=1
	lea	rax, [r8 + 4*r9]
.LBB0_20:                               # %L57
                                        #   Parent Loop BB0_7 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rax + 4*rdx]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm1, dword ptr [rcx + 4*rdx]   # xmm1 = mem[0],zero,zero,zero
	add	rdx, 1
	cmp	r10, rdx
	vfmadd231ss	xmm11, xmm0, xmm0       # xmm11 = (xmm0 * xmm0) + xmm11
	vfmadd231ss	xmm2, xmm1, xmm0        # xmm2 = (xmm1 * xmm0) + xmm2
	vfmadd231ss	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	jne	.LBB0_20
	jmp	.LBB0_30
.LBB0_104:                              # %L1049.loopexit691
	mov	rax, qword ptr [rbx + 64]       # 8-byte Reload
	mov	rdx, qword ptr [rbx + 168]      # 8-byte Reload
	mov	qword ptr [rbx + 216], r15
	mov	qword ptr [rbx + 208], rax
	jmp	.LBB0_206
.LBB0_106:
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_206
.LBB0_5:
	mov	rdx, qword ptr [rbx + 168]      # 8-byte Reload
	vxorps	xmm0, xmm0, xmm0
.LBB0_206:                              # %L1049
	mov	rax, qword ptr [rbx + 104]
	mov	qword ptr [rdx], rax
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_242:                              # %L693.split.us
	movabs	rax, 135794572797712
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 72]
	mov	edx, 1
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_233:                              # %L171.split.us
	movabs	rax, 135794572797712
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 72]
	mov	edx, 1
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_109:                              # %oob281
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_220
.LBB0_111:                              # %oob281
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_111
.LBB0_220:                              # %oob281
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_249:                              # %L1012
	movabs	rax, offset j__refuse_curvature_1814
	mov	rdi, r15
	vzeroupper
	call	rax
.LBB0_243:                              # %L713
	movabs	rax, offset j_throw_boundserror_1810
	lea	rsi, [rbx + 200]
	mov	qword ptr [rbx + 200], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_176:                              # %oob364
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_225
.LBB0_178:                              # %oob364
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_178
.LBB0_225:                              # %oob364
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_250:                              # %L1031
	movabs	rax, 135794568852048
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 72]
	mov	edx, 1
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_8:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_207
.LBB0_10:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_10
.LBB0_207:                              # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_240:                              # %L490
	movabs	rax, offset j__refuse_curvature_1814
	mov	rdi, r15
	vzeroupper
	call	rax
.LBB0_234:                              # %L191
	movabs	rax, offset j_throw_boundserror_1810
	lea	rsi, [rbx + 216]
	mov	qword ptr [rbx + 216], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_75:                               # %oob89
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_212
.LBB0_77:                               # %oob89
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_77
.LBB0_212:                              # %oob89
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r15
	vzeroupper
	call	rax
.LBB0_241:                              # %L509
	movabs	rax, 135794568852048
	movabs	rdi, 135794436290208
	lea	rsi, [rbx + 72]
	mov	edx, 1
	mov	qword ptr [rbx + 72], rax
	movabs	rax, offset ijl_apply_generic
	vzeroupper
	call	rax
	movabs	rcx, offset ijl_throw
	mov	rdi, rax
	call	rcx
.LBB0_248:                              # %L949
	movabs	rax, offset j_throw_boundserror_1810
	lea	rsi, [rbx + 192]
	mov	qword ptr [rbx + 192], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_239:                              # %L427
	movabs	rax, offset j_throw_boundserror_1810
	lea	rsi, [rbx + 208]
	mov	qword ptr [rbx + 208], r15
	mov	qword ptr [rbx + 112], rdi
	vzeroupper
	call	rax
.LBB0_244:                              # %L753
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm11
	vzeroupper
	call	rax
.LBB0_235:                              # %L231
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm11
	vzeroupper
	call	rax
.LBB0_221:                              # %oob334
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_224
.LBB0_223:                              # %oob334
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_223
.LBB0_224:                              # %oob334
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r15
	vzeroupper
	call	rax
.LBB0_208:                              # %oob60
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_211
.LBB0_210:                              # %oob60
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_210
.LBB0_211:                              # %oob60
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 2
	mov	qword ptr [rsi], 1
	mov	qword ptr [rsi + 8], r15
	vzeroupper
	call	rax
.LBB0_245:                              # %L818
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_246:                              # %L825
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_247:                              # %L832
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_236:                              # %L296
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vzeroupper
	call	rax
.LBB0_237:                              # %L303
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_238:                              # %L310
	movabs	rax, offset j_throw_complex_domainerror_1811
	movabs	rdi, 135794596555280
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_188:                              # %oob420
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_226
.LBB0_190:                              # %oob420
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_190
.LBB0_226:                              # %oob420
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_228:                              # %oob430
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_231
.LBB0_230:                              # %oob430
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_230
.LBB0_231:                              # %oob430
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_87:                               # %oob147
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_213
.LBB0_89:                               # %oob147
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_89
.LBB0_213:                              # %oob147
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_215:                              # %oob157
	mov	rsi, rsp
	mov	ecx, 16
	sub	rsi, rcx
	cmp	rsi, rsp
	jge	.LBB0_218
.LBB0_217:                              # %oob157
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_217
.LBB0_218:                              # %oob157
	mov	rsp, rsi
	mov	qword ptr [rsi], rax
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	"julia__sweep!_1804", .Lfunc_end0-"julia__sweep!_1804"
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
