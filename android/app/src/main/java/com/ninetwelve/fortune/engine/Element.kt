package com.ninetwelve.fortune.engine

/** 五行。 */
enum class Element(val zh: String) {
    METAL("金"),
    WOOD("木"),
    WATER("水"),
    FIRE("火"),
    EARTH("土");

    /** 我所生者（木生火、火生土、土生金、金生水、水生木）。 */
    val generates: Element
        get() = when (this) {
            WOOD -> FIRE
            FIRE -> EARTH
            EARTH -> METAL
            METAL -> WATER
            WATER -> WOOD
        }

    /** 我所剋者（木剋土、土剋水、水剋火、火剋金、金剋木）。 */
    val overcomes: Element
        get() = when (this) {
            WOOD -> EARTH
            EARTH -> WATER
            WATER -> FIRE
            FIRE -> METAL
            METAL -> WOOD
        }

    /** 屬於此五行的所有宮位。 */
    val palaces: List<Int>
        get() = (1..12).filter { of(it) == this }

    /** 五行名稱。譯法採用各語言命理文獻通用的說法。 */
    fun name(lang: Lang): String = when (lang) {
        Lang.ZH -> zh
        Lang.EN -> when (this) {
            METAL -> "Metal"; WOOD -> "Wood"; WATER -> "Water"; FIRE -> "Fire"; EARTH -> "Earth"
        }
        Lang.ES -> when (this) {
            METAL -> "Metal"; WOOD -> "Madera"; WATER -> "Agua"; FIRE -> "Fuego"; EARTH -> "Tierra"
        }
        Lang.IT -> when (this) {
            METAL -> "Metallo"; WOOD -> "Legno"; WATER -> "Acqua"; FIRE -> "Fuoco"; EARTH -> "Terra"
        }
    }

    companion object {
        /**
         * 十二宮的五行歸屬。
         *
         * 金：2宮、7宮
         * 木：9宮、12宮
         * 水：3宮、4宮、6宮
         * 火：1宮、5宮、8宮
         * 土：10宮、11宮
         */
        fun of(palace: Int): Element = when (Num.r12(palace)) {
            2, 7 -> METAL
            9, 12 -> WOOD
            3, 4, 6 -> WATER
            1, 5, 8 -> FIRE
            else -> EARTH // 10, 11
        }
    }
}
