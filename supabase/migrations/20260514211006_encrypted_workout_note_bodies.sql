alter table public.workout_notes
  add column if not exists body_ciphertext text,
  add column if not exists body_nonce text,
  add column if not exists body_key_version integer not null default 1,
  add column if not exists body_encryption_alg text not null default 'AES-256-GCM';

comment on column public.workout_notes.body is
  'Legacy/plaintext note body column. V1 clients must write an empty string and store encrypted note text in body_ciphertext/body_nonce.';

comment on column public.workout_notes.body_ciphertext is
  'Base64 client-side encrypted workout note body package. The decryption key is stored on device, not in Supabase.';

comment on column public.workout_notes.body_nonce is
  'Base64 AES-GCM nonce for body_ciphertext.';

comment on column public.workout_notes.body_key_version is
  'Client encryption key version for future rotation.';

comment on column public.workout_notes.body_encryption_alg is
  'Client encryption algorithm for body_ciphertext.';
