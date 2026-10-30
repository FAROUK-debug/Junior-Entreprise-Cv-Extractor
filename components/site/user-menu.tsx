"use client";
// The account menu in the header, shown only when someone is logged in.
import Link from "next/link";
import { UserIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { Role } from "@/lib/auth";
import en from "@/messages/en.json";

const spaceFor: Record<Role, string> = { candidate: "/candidate", company: "/company", admin: "/admin" };

export function UserMenu({ email, role }: { email: string; role: Role | null }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger render={<Button variant="outline" size="icon" aria-label={en.site.userMenu.open} />}>
        <UserIcon />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-56">
        <DropdownMenuGroup>
          <DropdownMenuLabel>
            <span className="block text-xs text-muted-foreground">{en.site.userMenu.signedInAs}</span>
            <span className="block truncate font-medium text-foreground">{email}</span>
            <span className="block text-xs text-muted-foreground">
              {role ? en.site.roles[role] : en.site.userMenu.noRole}
            </span>
          </DropdownMenuLabel>
        </DropdownMenuGroup>
        {role && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuItem render={<Link href={spaceFor[role]} />}>{en.site.userMenu.mySpace}</DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
