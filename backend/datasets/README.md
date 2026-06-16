# Okuma Metni Veri Seti

Bu klasörde uygulamada kullanılacak seviyelendirilmiş okuma metinleri tutulur.

## Dosya

- `reading_texts.csv`

## Kolonlar

- `level_id`: Metnin bağlı olduğu seviye.
- `title`: Uygulamada görünen metin başlığı.
- `level`: Kolay, Orta veya Zor gibi zorluk etiketi.
- `content`: Çocuğun okuyacağı asıl metin.
- `target_letters`: Metnin özellikle çalıştırdığı harf veya sesler.
- `target_skill`: Metnin pedagojik hedefi.
- `word_count`: Metindeki kelime sayısı.

## İçe Aktarma

Backend klasörü proje içindeyken şu komut çalıştırılır:

```bash
python backend/import_dataset.py
```

Script aynı başlık veya aynı içerik varsa mevcut kaydı günceller, yoksa yeni kayıt ekler.
