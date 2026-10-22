package com.ninetwelve.fortune.engine

import kotlin.math.abs

/**
 * 基礎數字運算：九進制、十二進制與生命靈數化約。
 *
 * 系統中所有宮位以 1..12 表示（十二進制），靈數以 1..9 表示（九進制）。
 * 這裡的「進制」指的是循環化約，而非數字的底數表示法。
 *
 * 與 iOS 版 `Engine/Numerology.swift` 逐行對應，不得擅自更動規則。
 */
object Num {

    /**
     * 十二進制化約：把任意正整數摺疊回 1..12。
     * 例：13 → 1，15 → 3，24 → 12，12 → 12
     */
    fun r12(n: Int): Int {
        val m = (n - 1) % 12
        return (if (m < 0) m + 12 else m) + 1
    }

    /**
     * 九進制化約：把任意正整數摺疊回 1..9。
     * 例：10 → 1，21 → 3，18 → 9
     */
    fun r9(n: Int): Int {
        val m = (n - 1) % 9
        return (if (m < 0) m + 9 else m) + 1
    }

    /** 各位數字之和。例：17 → 8，2006 → 8 */
    fun digitSum(n: Int): Int {
        var v = abs(n)
        var s = 0
        while (v > 0) {
            s += v % 10
            v /= 10
        }
        return s
    }

    /**
     * 生命靈數化約：反覆取各位數字之和，直到落在 1..9。
     * 例：2006 → 8，1996 → 25 → 7，19 → 10 → 1
     */
    fun lifeDigit(n: Int): Int {
        var v = abs(n)
        while (v > 9) {
            v = digitSum(v)
        }
        return if (v == 0) 9 else v
    }
}
