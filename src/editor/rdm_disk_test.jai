test_f32_to_f16 :: () {
    s := begin_suite("f32_to_f16");

    check(*s, "0.0 → 0x0000",   f32_to_f16(0.0)     == 0x0000);
    check(*s, "-0.0 → 0x8000",  f32_to_f16(-0.0)    == 0x8000);
    check(*s, "1.0 → 0x3C00",   f32_to_f16(1.0)     == 0x3C00);
    check(*s, "-1.0 → 0xBC00",  f32_to_f16(-1.0)    == 0xBC00);
    check(*s, "0.5 → 0x3800",   f32_to_f16(0.5)     == 0x3800);
    check(*s, "2.0 → 0x4000",   f32_to_f16(2.0)     == 0x4000);
    check(*s, "1.5 → 0x3E00",   f32_to_f16(1.5)     == 0x3E00);

    // Max normal f16 = 65504
    check(*s, "65504.0 → 0x7BFF", f32_to_f16(65504.0) == 0x7BFF);

    // Min normal f16 = 2^-14
    check(*s, "2^-14 → 0x0400",  f32_to_f16(cast(float)(1.0 / 16384.0)) == 0x0400);

    // Overflow clamps to infinity
    check(*s, "65536.0 → 0x7C00 (inf)",   f32_to_f16(65536.0)  == 0x7C00);
    check(*s, "1e10 → 0x7C00 (inf)",      f32_to_f16(1.0e10)   == 0x7C00);
    check(*s, "-65536.0 → 0xFC00 (-inf)", f32_to_f16(-65536.0) == 0xFC00);

    // Denormals: 2^-15 is the largest f16 denormal base
    check(*s, "2^-15 → 0x0200",  f32_to_f16(cast(float)(1.0 / 32768.0))    == 0x0200);
    // Smallest representable f16 denormal = 2^-24
    check(*s, "2^-24 → 0x0001",  f32_to_f16(cast(float)(1.0 / 16777216.0)) == 0x0001);

    // Underflow to zero
    check(*s, "2^-25 → 0x0000",  f32_to_f16(cast(float)(1.0 / 33554432.0))  == 0x0000);
    check(*s, "-2^-25 → 0x8000", f32_to_f16(cast(float)(-1.0 / 33554432.0)) == 0x8000);

    end_suite(s);
}

#run test_f32_to_f16();
