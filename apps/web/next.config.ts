import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "trybram.app",
        pathname: "/screenshots/**",
      },
    ],
  },
};

export default nextConfig;
