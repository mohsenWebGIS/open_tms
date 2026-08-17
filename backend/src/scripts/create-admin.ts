#!/usr/bin/env tsx
import { PrismaClient } from '@prisma/client';
import { randomBytes, createHmac } from 'crypto';
import { seedSystemRoles } from '../auth/seedRoles.js';

function usage() {
  console.error(`Usage: npx tsx backend/src/scripts/create-admin.ts --email user@example.com --password "Secret1!" [--firstName First --lastName Last] [--orgId ORG_ID]`);
  process.exit(1);
}

function parseArg(name: string) {
  const idx = process.argv.indexOf(name);
  if (idx === -1 || idx === process.argv.length - 1) return undefined;
  return process.argv[idx + 1];
}

async function hashPassword(password: string) {
  const salt = randomBytes(16).toString('hex');
  const hash = createHmac('sha256', salt).update(password).digest('hex');
  return `${salt}:${hash}`;
}

async function main() {
  const email = parseArg('--email');
  const password = parseArg('--password');
  const firstName = parseArg('--firstName') || 'Admin';
  const lastName = parseArg('--lastName') || 'User';
  const orgIdArg = parseArg('--orgId');

  if (!email || !password) usage();

  const prisma = new PrismaClient();
  try {
    // Ensure system roles exist (idempotent)
    await seedSystemRoles(prisma as any);

    // Determine organization
    let orgId = orgIdArg;
    if (!orgId) {
      const org = await prisma.organization.findFirst();
      if (org) orgId = org.id;
      else {
        const created = await prisma.organization.create({ data: { name: 'Default Organization' } });
        orgId = created.id;
        console.log('Created organization', orgId);
      }
    }

    // Check existing user
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      console.error(`User with email ${email} already exists (id=${existing.id}). Aborting.`);
      process.exit(1);
    }

    const passwordHash = await hashPassword(password);

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash,
        firstName,
        lastName,
        organizationId: orgId,
        timezone: 'UTC',
      },
    });

    // Assign admin role
    const adminRole = await prisma.role.findUnique({ where: { name: 'admin' } });
    if (!adminRole) {
      console.warn('Admin role not found after seeding roles. Created roles should include admin.');
    } else {
      await prisma.userRole.create({ data: { userId: user.id, roleId: adminRole.id } });
    }

    console.log('Created admin user:');
    console.log(`  id: ${user.id}`);
    console.log(`  email: ${email}`);
    console.log('Assign admin role: done');
  } catch (err) {
    console.error('Error creating admin user:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();
