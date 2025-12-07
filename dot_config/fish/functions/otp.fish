# Pass OTP 2fa with fzf
function otp
    set -l otp_entry (find ~/.password-store -name "*.gpg" -type f \
        | sed 's|^.*\.password-store/||' \
        | sed 's|\.gpg$||' \
        | fzf --header 'Select OTP to copy')

    test -n "$otp_entry"; and pass otp -c "$otp_entry"
end
