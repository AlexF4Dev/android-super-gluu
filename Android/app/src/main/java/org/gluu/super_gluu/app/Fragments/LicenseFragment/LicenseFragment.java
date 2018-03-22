package org.gluu.super_gluu.app.fragments.LicenseFragment;

import android.content.Context;
import android.os.Bundle;
import android.support.v7.widget.Toolbar;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.ProgressBar;

import org.gluu.super_gluu.app.base.ToolbarFragment;
import org.gluu.super_gluu.app.listener.OnMainActivityListener;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import SuperGluu.app.R;
import butterknife.BindView;
import butterknife.ButterKnife;

/**
 * Created by nazaryavornytskyy on 3/22/16.
 */
public class LicenseFragment extends ToolbarFragment {

    OnMainActivityListener mainActivityListener;

    @BindView(R.id.nav_drawer_toolbar)
    Toolbar toolbar;

    @BindView(R.id.license_webView)
    WebView licenseWebView;

    @BindView(R.id.license_progress_bar)
    ProgressBar progressBar;

    @BindView(R.id.accept_button)
    Button acceptButton;

    private Boolean isFirstTimeLoading;
    private Type type;

    public enum Type {
        PRIVACY, TERMS_OF_SERVICE
    }

    public static LicenseFragment newInstance(boolean firstTimeLoading, Type type) {
        LicenseFragment licenseFragment = new LicenseFragment();
        Bundle bundle = new Bundle();
        bundle.putBoolean(Constant.IS_FIRST_TIME_LOADING, firstTimeLoading);
        bundle.putSerializable(Constant.LICENSE_TYPE, type);
        licenseFragment.setArguments(bundle);

        return licenseFragment;
    }

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);
        if (context instanceof OnMainActivityListener) {
            mainActivityListener = (OnMainActivityListener) context;
        } else {
            throw new RuntimeException(context.toString()
                    + " must implement OnMainActivityListener");
        }
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {

        View view = inflater.inflate(R.layout.license_fragment, container, false);
        ButterKnife.bind(this, view);

        setHasOptionsMenu(true);

        isFirstTimeLoading = getArguments().getBoolean(Constant.IS_FIRST_TIME_LOADING, false);
        type = (Type) getArguments().getSerializable(Constant.LICENSE_TYPE);

        acceptButton.setOnClickListener(v -> mainActivityListener.onLicenseAgreement());

        if (isFirstTimeLoading && type == Type.PRIVACY){
            acceptButton.setVisibility(View.VISIBLE);
            setDefaultToolbar(toolbar, getString(R.string.privacy_policy), false);
        } else {
            acceptButton.setVisibility(View.GONE);
            if(type == Type.PRIVACY) {
                setDefaultToolbar(toolbar, getString(R.string.privacy_policy), true);
            } else {
                setDefaultToolbar(toolbar, getString(R.string.user_guide), true);
            }
        }

        licenseWebView.setWebViewClient(new WebViewClient() {
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                view.loadUrl(url);
                return false;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                progressBar.setVisibility(View.GONE);
            }
        });


        licenseWebView.loadUrl(getUrl());

        return view;
    }

    private String getUrl() {
        switch (type) {
            case PRIVACY:
                return Constant.PRIVACY_POLICY_URL;
            case TERMS_OF_SERVICE:
                return Constant.USER_GUIDE_URL;
            default:
                return Constant.PRIVACY_POLICY_URL;
        }

    }

    //Unused but keeping this in case we need to load HTML directly form project again
    private String readLicenseTxt(){

        InputStream inputStream = getResources().openRawResource(R.raw.license_eula);
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();

        int i;
        try {
            i = inputStream.read();
            while (i != -1)
            {
                byteArrayOutputStream.write(i);
                i = inputStream.read();
            }
            inputStream.close();
        } catch (IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }

        return byteArrayOutputStream.toString();
    }

    public class Constant {
        private static final String IS_FIRST_TIME_LOADING = "is_first_time_loading";
        private static final String LICENSE_TYPE = "license_type";

        private static final String PRIVACY_POLICY_URL = "https://docs.google.com/document/d/1E1xWq28_f-tam7PihkTZXhlqaXVGZxJbVt4cfx15kB4";
        private final static String USER_GUIDE_URL = "https://gluu.org/docs/supergluu/3.0.0/user-guide/";
    }
}
