import type { Metadata } from "next";
import { PasswordResetForm } from "./password-reset-form";

export const metadata: Metadata = {
  title: "Reset Password",
  description: "Reset your Bram account password.",
};

export default function ResetPasswordPage() {
  return <PasswordResetForm />;
}
