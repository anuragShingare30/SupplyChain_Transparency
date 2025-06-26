import { ConnectButton } from '@rainbow-me/rainbowkit';

export default function Home() {
  return (
    <div>
      <ConnectButton 
        label="Sign in" 
        chainStatus="name" 
        accountStatus={{
          smallScreen: 'avatar',
          largeScreen: 'full',
            }}
            showBalance={{
              smallScreen: false,
              largeScreen: true,
            }}
      />
    </div>
  );
}
