# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-15

### Added

- Azure Automanage configuration profile with antimalware, backup, and log analytics integration
- Maintenance configuration with configurable maintenance windows and in-guest patching for Linux and Windows
- Per-VM maintenance assignment for all managed virtual machines
- Recovery Services Vault with geo-redundant storage and soft delete enabled
- VM backup policy with daily/weekly scheduling and multi-tier retention (daily, weekly, monthly, yearly)
- Per-VM backup protection using Recovery Services Vault
- Log Analytics workspace with Updates and Security solutions
- Custom Azure Policy definitions and assignments for compliance enforcement
- Built-in policy assignments for VM backup and monitoring agent requirements
- Monitor action group with configurable email receivers
- Metric alerts for CPU utilization, available memory, disk IOPS, and VM availability
- Automation account with system-assigned managed identity
- Configurable automation runbooks for auto-remediation (default: VM restart runbook)
- Diagnostic settings for Recovery Services Vault and Automation Account
- Role assignment for Automation Account to manage virtual machines
