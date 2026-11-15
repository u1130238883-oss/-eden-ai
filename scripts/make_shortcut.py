"""Builds the unsigned shortcuts bundled in the app.

    make_shortcut.py <kind> <out.shortcut>

kinds
  lock  潮流換壁紙       [Get Clipboard] -> [Set Wallpaper]                 (proven on the user's iPhone)
  home  潮流換壁紙主畫面  [Get Clipboard] -> [Set Wallpaper: Home Screen]
  both  潮流換壁紙兩者    [Get Clipboard] -> [Set Wallpaper] -> [Set Wallpaper: Home Screen]
  auto  潮流自動換壁紙    [URL streetwall://auto] -> [Open URL]
        (the app then advances the channel and runs the lock/home/both
         shortcut itself, i.e. the same proven path as 一鍵套用)

Each variant is its own shortcut so an iOS-side problem with one (e.g. the
Home Screen location parameter) cannot break the others. Only built-in
actions are used, so nothing depends on the bundle ID the sideloader assigns.
"""
import plistlib, sys, uuid

kind, out = sys.argv[1], sys.argv[2]


def uid():
    return str(uuid.uuid4()).upper()


def ref(u, name):
    return {
        "Value": {"Type": "ActionOutput", "OutputUUID": u, "OutputName": name},
        "WFSerializationType": "WFTextTokenAttachment",
    }


def get_clipboard(u):
    return {"WFWorkflowActionIdentifier": "is.workflow.actions.getclipboard",
            "WFWorkflowActionParameters": {"UUID": u}}


def current_poster(u_all, u_one):
    """[Get Current Wallpaper] -> [Get First Item]. Feeding this into
    WFSelectedPoster makes Set Wallpaper UPDATE the wallpaper the user is using
    (keeping its Home Screen "Coppia" setting) instead of creating a new one,
    whose Home Screen defaults to a solid colour."""
    return [
        {"WFWorkflowActionIdentifier": "is.workflow.actions.posters.get",
         "WFWorkflowActionParameters": {"UUID": u_all, "WFPosterType": "Current"}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.getitemfromlist",
         "WFWorkflowActionParameters": {"UUID": u_one, "WFItemSpecifier": "First Item",
                                        "WFInput": ref(u_all, "Wallpapers")}},
    ]


def set_wallpaper(u, poster, home_only=False):
    p = {
        "WFInput": ref(u, "Clipboard"),
        "WFSelectedPoster": ref(poster, "Item from List"),
        "WFWallpaperShowPreview": False,
        "WFWallpaperSmartCrop": False,
        # Default is True: iOS re-enables the Home Screen "Sfocatura" (blur) on
        # every run, which turns a dark wallpaper into a flat solid colour.
        "WFWallpaperLegibilityBlur": False,
    }
    if home_only:
        p["WFWallpaperLocation"] = ["Home Screen"]
    return {"WFWorkflowActionIdentifier": "is.workflow.actions.wallpaper.set",
            "WFWorkflowActionParameters": p}


c, pa, p1 = uid(), uid(), uid()
if kind == "lock":
    actions = [get_clipboard(c), *current_poster(pa, p1), set_wallpaper(c, p1)]
elif kind == "both":
    # Lock Screen first, then the Home Screen as its own photo: iOS forces blur
    # on a paired ("Abbinata") Home Screen, a separate Home photo may stay sharp.
    actions = [get_clipboard(c), *current_poster(pa, p1), set_wallpaper(c, p1),
               set_wallpaper(c, p1, home_only=True)]
elif kind == "home":
    actions = [get_clipboard(c), *current_poster(pa, p1), set_wallpaper(c, p1, home_only=True)]
elif kind == "auto":
    u = uid()
    actions = [
        {"WFWorkflowActionIdentifier": "is.workflow.actions.url",
         "WFWorkflowActionParameters": {"UUID": u, "WFURLActionURL": "streetwall://auto"}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
         "WFWorkflowActionParameters": {"WFInput": ref(u, "URL")}},
    ]
else:
    sys.exit(f"unknown kind {kind}")

doc = {
    "WFWorkflowActions": actions,
    "WFWorkflowClientVersion": "2302.0.4",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4292093695, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowTypes": [],
    "WFWorkflowHasShortcutInputVariables": False,
    "WFQuickActionSurfaces": [],
}
with open(out, "wb") as f:
    plistlib.dump(doc, f, fmt=plistlib.FMT_BINARY)
print("wrote", kind, out)
