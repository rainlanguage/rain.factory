// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.18;

/// @title ICloneableV1
/// @notice Minimal interface following the Open Zeppelin conventions for
/// initializing a cloned proxy.
interface ICloneableV1 {
    /// Initialize is intended to work like constructors but for cloneable
    /// proxies. The `ICloneableV1` contract MUST ensure that initialize can NOT
    /// be called more than once. The `ICloneableV1` contract is designed to be
    /// deployed by an `ICloneFactoryV1` but MUST NOT assume that it will be. It
    /// is possible for someone to directly deploy an `ICloneableV1` and fail to
    /// call initialize before other functions are called, and end users MAY NOT
    /// realise or know how to confirm a safe deployment state. The
    /// `ICloneableV1` MUST take appropriate measures to ensure that functions
    /// called before initialize are safe to do so, or revert.
    ///
    /// To be fully generic `initilize` accepts `bytes` and so MUST ABI decode
    /// within the initialize function. This allows the factory to service
    /// arbitrary cloneable proxies but also erases the type of the
    /// initialization config from the ABI. One workaround is to emit an event
    /// containing the initialization config type, so that the type appears
    /// within the event and therefore the ABI.
    /// @param data The initialization data.
    function initialize(bytes calldata data) external;
}
