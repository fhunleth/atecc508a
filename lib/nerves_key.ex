defmodule NervesKey do
  @moduledoc """
  This is a high level interface to provisioning and using the Nerves Key
  or any ATECC508A/608A that can be configured similarly.
  """

  alias NervesKey.{Config, OTP, Data}

  @doc """
  Configure an ATECC508A or ATECC608A as a Nerves Key.
  """
  def configure(transport) do
    cond do
      Config.config_compatible?(transport) == {:ok, true} -> :ok
      Config.configured?(transport) == {:ok, true} -> {:error, :config_locked}
      true -> Config.configure(transport)
    end
  end

  @doc """
  Create a signing key pair

  This returns a tuple that contains the certificate and the private key.
  """
  def create_signing_key_pair() do
    ATECC508A.Certificate.new_signer(1)
  end

  @doc """
  Provision a NervesKey in one step

  This function does it all, but it requires the signer's private key.
  """
  @spec provision(
          ATECC508A.Transport.t(),
          NervesKey.ProvisioningInfo.t(),
          X509.Certificate.t(),
          X509.PrivateKey.t()
        ) :: :ok
  def provision(transport, info, signer_cert, signer_key) do
    :ok = configure(transport)
    otp_info = OTP.new(info.board_name, info.manufacturer_sn)
    :ok = OTP.write(transport, otp_info)
    {:ok, device_public_key} = Data.genkey(transport)
    {:ok, device_sn} = Config.device_sn(transport)

    device_cert =
      ATECC508A.Certificate.new_device(
        device_public_key,
        device_sn,
        info.manufacturer_sn,
        signer_cert,
        signer_key
      )

    :ok = Data.write_certificates(transport, device_cert, signer_cert)
    # :ok = Data.lock(transport)
  end
end
