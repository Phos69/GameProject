# 🔄 Rigenerazione Completa del Progetto

Questa cartella contiene script per rigenerare completamente il progetto Godot, eliminando tutte le cache e i file generati.

## 📋 Cosa fa?

Lo script di rigenerazione:
1. ✅ Elimina la cache di Godot (`.godot/`)
2. ✅ Elimina la cartella build
3. ✅ Ripulisce i file di export
4. ✅ Rimuove i file temporanei
5. ✅ Ricrea la struttura di base di Godot

## 🚀 Come usare

### **Windows (PowerShell)**

```powershell
# Apri PowerShell e naviga alla cartella del progetto
cd "e:\AI_TEST\GameProject"

# Esegui lo script
.\regenerate_game.ps1
```

**Nota:** Se ricevi un errore di esecuzione, esegui prima:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **Mac/Linux o Git Bash**

```bash
# Naviga alla cartella del progetto
cd "path/to/GameProject"

# Rendi eseguibile lo script
chmod +x regenerate_game.sh

# Esegui lo script
./regenerate_game.sh
```

## ⚙️ Dopo la rigenerazione

1. **Apri il progetto in Godot Editor**
   - Godot ricostruirà automaticamente tutte le cache
   - Reimporterà tutte le risorse
   - Ricompilerà tutti i script

2. **Attendi il completamento**
   - Guarda la barra di progresso in basso
   - Il processo può durare qualche minuto

3. **Verifica il funzionamento**
   - Controlla che tutte le scene si carichino correttamente
   - Testa il gameplay base
   - Verifica che nessun errore sia nei log

## 🔍 Se qualcosa non funziona

Se dopo la rigenerazione riscontri problemi:

1. **Riavvia Godot completamente**
2. **Controlla i file di progetto** (potrebbero essere corrotti)
3. **Esegui di nuovo lo script** per una pulizia più profonda
4. **Svuota il cestino** per assicurarti che i file siano davvero eliminati

## 📝 File coinvolti

- `.godot/` - Cache e file compilati di Godot
- `.godot/imported/` - Cache delle risorse importate
- `.godot/editor/` - Stato dell'editor
- `build/` - Cartella di build
- File `.tmp` - File temporanei

## ⚡ Alternativa veloce da terminale

Se preferisci una soluzione manuale:

```bash
# Eliminare tutte le cache
rm -rf .godot/
rm -rf build/

# Riapri Godot per rigenerare tutto
```

---

**Creato per il progetto Iso Local Sandbox**
