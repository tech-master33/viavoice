import wx
import winreg
import win32com.client
import pythoncom

VOICE_NAMES = [
    "Wade","Shelly","Bobbie","Roko","Glenn","Female2","Grandma","Grandpa",
    "Smooth","Deep","Mix","Resonant","Cheerful","Warm","Marble","Echo",
    "Bold","Crystal","Mellow","Vibrant"
]

REG_ROOT = r"Software\ViaVoice\Voices"

PARAM_KEYS = ["PitchBaseline","PitchFluctuation","Speed","Roughness","Breathiness","HeadSize"]
PARAM_ATTRS = ["pitch_baseline","pitch_fluctuation","speed","roughness","breathiness","head_size"]
PARAM_LABELS = ["Pitch Baseline","Fluctuation","Speed","Roughness","Breathiness","Head Size"]

class VoiceProfile:
    def __init__(self, index):
        self.index = index
        self.name = VOICE_NAMES[index] if index < len(VOICE_NAMES) else f"Voice{index+1}"
        self.enabled = True
        self.base_voice = min(index + 1, 8)
        self.gender = 0
        self.age = 0
        self.pitch_baseline = 60
        self.pitch_fluctuation = 50
        self.speed = 50
        self.roughness = 0
        self.breathiness = 0
        self.head_size = 50
        self._set_defaults()

    def _set_defaults(self):
        v = self.index + 1
        if v <= 8:
            self.base_voice = v
            self.pitch_baseline = 30 if v == 7 else (55 if v == 8 else 60)
            self.pitch_fluctuation = 30 if v in (7,8) else 50
            self.gender = 1 if v in (2,6,7) else 0
            self.age = 1 if v == 3 else 0
        else:
            if v <= 16:
                self.base_voice = v
            else:
                self.base_voice = v - 16
            defaults = {
                9:  {"pitch_fluctuation": 30, "breathiness": 40},
                10: {"pitch_baseline": 40, "head_size": 70, "speed": 30},
                11: {"pitch_baseline": 55, "pitch_fluctuation": 60},
                12: {"head_size": 80, "breathiness": 20},
                13: {"pitch_baseline": 70, "speed": 70},
                14: {"breathiness": 50, "pitch_fluctuation": 25},
                15: {"pitch_fluctuation": 15, "roughness": 10},
                16: {"pitch_fluctuation": 70, "roughness": 30},
                17: {"pitch_baseline": 35, "roughness": 40},
                18: {"pitch_baseline": 75, "pitch_fluctuation": 35},
                19: {"pitch_fluctuation": 20, "speed": 40},
                20: {"pitch_fluctuation": 65, "speed": 80, "pitch_baseline": 65},
            }
            if v in defaults:
                for k, val in defaults[v].items():
                    setattr(self, k, val)

    def load(self):
        key_path = f"{REG_ROOT}\\Voice{self.index+1}"
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path) as key:
                for i in range(winreg.QueryInfoKey(key)[1]):
                    name, value, _ = winreg.EnumValue(key, i)
                    if name == "Name" and isinstance(value, str):
                        self.name = value
                    elif name == "Enabled":
                        self.enabled = bool(value)
                    elif name == "BaseVoice":
                        self.base_voice = value
                    elif name == "Gender":
                        self.gender = value
                    elif name == "Age":
                        self.age = value
                    elif name in PARAM_KEYS:
                        idx = PARAM_KEYS.index(name)
                        setattr(self, PARAM_ATTRS[idx], value)
        except FileNotFoundError:
            pass

    def save(self):
        key_path = f"{REG_ROOT}\\Voice{self.index+1}"
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, key_path) as key:
            winreg.SetValueEx(key, "Name", 0, winreg.REG_SZ, self.name)
            winreg.SetValueEx(key, "Enabled", 0, winreg.REG_DWORD, 1 if self.enabled else 0)
            winreg.SetValueEx(key, "BaseVoice", 0, winreg.REG_DWORD, self.base_voice)
            winreg.SetValueEx(key, "Gender", 0, winreg.REG_DWORD, self.gender)
            winreg.SetValueEx(key, "Age", 0, winreg.REG_DWORD, self.age)
            for i, pk in enumerate(PARAM_KEYS):
                winreg.SetValueEx(key, pk, 0, winreg.REG_DWORD, getattr(self, PARAM_ATTRS[i]))


class EditDialog(wx.Dialog):
    def __init__(self, parent, profile, base_voice_names, title="Edit Voice"):
        super().__init__(parent, title=title, size=(420, 480))
        self.profile = profile
        self.base_voice_names = base_voice_names
        panel = wx.Panel(self)
        vsizer = wx.BoxSizer(wx.VERTICAL)

        ns = wx.BoxSizer(wx.HORIZONTAL)
        ns.Add(wx.StaticText(panel, label="Name:"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 8)
        self.txt_name = wx.TextCtrl(panel, value=profile.name)
        ns.Add(self.txt_name, 1)
        vsizer.Add(ns, 0, wx.EXPAND | wx.ALL, 5)

        self.chk_enabled = wx.CheckBox(panel, label="Enabled")
        self.chk_enabled.SetValue(profile.enabled)
        vsizer.Add(self.chk_enabled, 0, wx.ALL, 5)

        bs = wx.BoxSizer(wx.HORIZONTAL)
        bs.Add(wx.StaticText(panel, label="Base Voice:"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 8)
        self.cbo_base = wx.Choice(panel, choices=self.base_voice_names)
        bv = max(1, min(profile.base_voice, 8))
        self.cbo_base.SetSelection(bv - 1)
        bs.Add(self.cbo_base, 1)
        vsizer.Add(bs, 0, wx.EXPAND | wx.ALL, 5)

        self.sliders = []
        self.val_labels = []
        vals = [profile.pitch_baseline, profile.pitch_fluctuation, profile.speed,
                profile.roughness, profile.breathiness, profile.head_size]
        for i, label in enumerate(PARAM_LABELS):
            ss = wx.BoxSizer(wx.HORIZONTAL)
            ss.Add(wx.StaticText(panel, label=label + ":"), 0, wx.ALIGN_CENTER_VERTICAL | wx.RIGHT, 8)
            slider = wx.Slider(panel, minValue=0, maxValue=100, value=vals[i], size=(180, -1))
            ss.Add(slider, 1, wx.ALIGN_CENTER_VERTICAL)
            vl = wx.StaticText(panel, label=str(vals[i]), size=(35, -1))
            ss.Add(vl, 0, wx.ALIGN_CENTER_VERTICAL | wx.LEFT, 5)
            idx = i
            slider.Bind(wx.EVT_SCROLL, lambda e, i=idx: vl.SetLabel(str(self.sliders[i].GetValue())))
            vsizer.Add(ss, 0, wx.EXPAND | wx.ALL, 3)
            self.sliders.append(slider)
            self.val_labels.append(vl)

        vsizer.AddStretchSpacer()

        bsz = wx.BoxSizer(wx.HORIZONTAL)
        btn_ok = wx.Button(panel, wx.ID_OK, label="OK")
        btn_cancel = wx.Button(panel, wx.ID_CANCEL, label="Cancel")
        bsz.AddStretchSpacer()
        bsz.Add(btn_ok, 0, wx.RIGHT, 8)
        bsz.Add(btn_cancel)
        vsizer.Add(bsz, 0, wx.EXPAND | wx.ALL, 5)

        panel.SetSizer(vsizer)

    def get_profile(self):
        p = self.profile
        p.name = self.txt_name.GetValue()
        p.enabled = self.chk_enabled.GetValue()
        p.base_voice = self.cbo_base.GetSelection() + 1
        p.pitch_baseline = self.sliders[0].GetValue()
        p.pitch_fluctuation = self.sliders[1].GetValue()
        p.speed = self.sliders[2].GetValue()
        p.roughness = self.sliders[3].GetValue()
        p.breathiness = self.sliders[4].GetValue()
        p.head_size = self.sliders[5].GetValue()
        return p


class VoiceManagerFrame(wx.Frame):
    def __init__(self):
        super().__init__(None, title="ViaVoice Manager", size=(500, 420))
        self.profiles = []
        self.load_all_profiles()
        self.base_voice_names = [f"{i+1} - {VOICE_NAMES[i]}" for i in range(8)]

        panel = wx.Panel(self)
        sizer = wx.BoxSizer(wx.VERTICAL)

        self.listbox = wx.ListBox(panel, style=wx.LB_SINGLE)
        sizer.Add(self.listbox, 1, wx.EXPAND | wx.ALL, 5)

        bs = wx.BoxSizer(wx.HORIZONTAL)
        btn_add = wx.Button(panel, label="Add")
        btn_add.Bind(wx.EVT_BUTTON, self.on_add)
        bs.Add(btn_add, 0, wx.RIGHT, 5)

        btn_edit = wx.Button(panel, label="Edit")
        btn_edit.Bind(wx.EVT_BUTTON, self.on_edit)
        bs.Add(btn_edit, 0, wx.RIGHT, 5)

        btn_delete = wx.Button(panel, label="Delete")
        btn_delete.Bind(wx.EVT_BUTTON, self.on_delete)
        bs.Add(btn_delete, 0, wx.RIGHT, 5)

        btn_test = wx.Button(panel, label="Speak Test")
        btn_test.Bind(wx.EVT_BUTTON, self.on_test)
        bs.Add(btn_test, 0, wx.RIGHT, 5)

        btn_reset = wx.Button(panel, label="Reset All")
        btn_reset.Bind(wx.EVT_BUTTON, self.on_reset)
        bs.Add(btn_reset)

        sizer.Add(bs, 0, wx.ALIGN_CENTER | wx.ALL, 5)

        panel.SetSizer(sizer)
        self.refresh_list()
        self.Show()

    def load_all_profiles(self):
        self.profiles.clear()
        # Load any Voice keys from registry
        seen = set()
        idx = 0
        while True:
            key_path = f"{REG_ROOT}\\Voice{idx+1}"
            try:
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path):
                    p = VoiceProfile(idx)
                    p.load()
                    self.profiles.append(p)
                    seen.add(idx)
                    idx += 1
            except FileNotFoundError:
                idx += 1
            if idx > 200:  # safety cap
                break
        # Fill in gaps (1-20 with defaults if not in registry)
        for i in range(20):
            if i not in seen:
                p = VoiceProfile(i)
                self.profiles.insert(i, p)

    def refresh_list(self):
        self.listbox.Clear()
        for p in self.profiles:
            self.listbox.Append(p.name)

    def find_next_index(self):
        used = {p.index for p in self.profiles}
        i = 0
        while i in used:
            i += 1
        return i

    def on_add(self, evt):
        idx = self.find_next_index()
        p = VoiceProfile(idx)
        p.name = f"Voice{idx+1}"
        dlg = EditDialog(self, p, self.base_voice_names, title="Add Voice")
        if dlg.ShowModal() == wx.ID_OK:
            p = dlg.get_profile()
            p.save()
            self.profiles.append(p)
            self.profiles.sort(key=lambda x: x.index)
            self.refresh_list()
        dlg.Destroy()

    def on_edit(self, evt):
        sel = self.listbox.GetSelection()
        if sel < 0:
            wx.MessageBox("Select a voice first.", "Edit")
            return
        p = self.profiles[sel]
        dlg = EditDialog(self, p, self.base_voice_names, title=f"Edit {p.name}")
        if dlg.ShowModal() == wx.ID_OK:
            p = dlg.get_profile()
            p.save()
            self.refresh_list()
            self.listbox.SetSelection(sel)
        dlg.Destroy()

    def on_delete(self, evt):
        sel = self.listbox.GetSelection()
        if sel < 0:
            return
        p = self.profiles[sel]
        dlg = wx.MessageDialog(self, f'Delete "{p.name}"?', "Confirm", wx.YES_NO | wx.ICON_QUESTION)
        if dlg.ShowModal() == wx.ID_YES:
            key_path = f"{REG_ROOT}\\Voice{p.index+1}"
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, key_path)
            except:
                pass
            self.profiles.pop(sel)
            self.refresh_list()
        dlg.Destroy()

    def on_test(self, evt):
        sel = self.listbox.GetSelection()
        if sel < 0:
            wx.MessageBox("Select a voice first.", "Test")
            return
        p = self.profiles[sel]
        p.save()
        pythoncom.CoInitialize()
        try:
            voice = win32com.client.Dispatch("SAPI.SpVoice")
            voices = voice.GetVoices()
            found = False
            for i in range(voices.Count):
                try:
                    name = voices.Item(i).GetAttribute("Name")
                    if name == p.name:
                        voice.Voice = voices.Item(i)
                        voice.Speak(f"This is a test of the {p.name} voice. Hello world.", 1)
                        found = True
                        break
                except:
                    pass
            if not found:
                wx.MessageBox(f'Voice "{p.name}" not found in SAPI. Register it first.', "Test Error")
        except Exception as ex:
            wx.MessageBox(f"Test failed: {ex}", "Test Error")

    def on_reset(self, evt):
        dlg = wx.MessageDialog(self, "Reset all voices to factory defaults?", "Confirm",
                               wx.YES_NO | wx.ICON_QUESTION)
        if dlg.ShowModal() == wx.ID_YES:
            try:
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_ROOT) as key:
                    for sub in [winreg.EnumKey(key, i) for i in range(winreg.QueryInfoKey(key)[0])]:
                        winreg.DeleteKey(winreg.HKEY_CURRENT_USER, f"{REG_ROOT}\\{sub}")
            except FileNotFoundError:
                pass
            self.load_all_profiles()
            self.refresh_list()
        dlg.Destroy()


if __name__ == "__main__":
    app = wx.App()
    VoiceManagerFrame()
    app.MainLoop()
