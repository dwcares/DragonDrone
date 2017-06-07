package com.bsherwin.MavicDragon;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.SurfaceTexture;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.TextureView;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.TextureView.SurfaceTextureListener;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.util.concurrent.ExecutionException;

import dji.common.product.Model;
import dji.sdk.base.BaseProduct;
import dji.sdk.camera.Camera;
import dji.sdk.camera.VideoFeeder;
import dji.sdk.codec.DJICodecManager;

public class MainActivity extends Activity implements SurfaceTextureListener,OnClickListener{

    private static final String TAG = MainActivity.class.getName();
    protected VideoFeeder.VideoDataCallback mReceivedVideoDataCallBack = null;

    // Codec for video live view
    protected DJICodecManager mCodecManager = null;

    protected TextureView mVideoSurface = null;
    protected TextView mText = null;
    private Button mCaptureBtn;
    private Bitmap mBitmap;

    private String cognitiveServicesBaseUrl = "https://westcentralus.api.cognitive.microsoft.com/face/v1.0";
    private String cognitiveServicesAPIKey = "";
    private String cognitiveServicesPersonGroup = "sherwin";

    @Override
    protected void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        initUI();

        // The callback for receiving the raw H264 video data for camera live view
        mReceivedVideoDataCallBack = new VideoFeeder.VideoDataCallback() {

            @Override
            public void onReceive(byte[] videoBuffer, int size) {
                if (mCodecManager != null) {
                    mCodecManager.sendDataToDecoder(videoBuffer, size);
                }
            }
        };
    }

    protected void onProductChange() {
        initPreviewer();
    }

    @Override
    public void onResume() {
        Log.e(TAG, "onResume");
        super.onResume();
        initPreviewer();
        onProductChange();

        if(mVideoSurface == null) {
            Log.e(TAG, "mVideoSurface is null");
        }
    }

    @Override
    public void onPause() {
        Log.e(TAG, "onPause");
        uninitPreviewer();
        super.onPause();
    }

    @Override
    public void onStop() { super.onStop(); }

    public void onReturn(View view){ this.finish(); }

    @Override
    protected void onDestroy() {
        Log.e(TAG, "onDestroy");
        uninitPreviewer();
        super.onDestroy();
    }

    private void initUI() {
        mVideoSurface = (TextureView)findViewById(R.id.video_previewer_surface);
        mText = (TextView) findViewById(R.id.analysis);
        mCaptureBtn = (Button) findViewById(R.id.btn_capture);

        if (null != mVideoSurface) {
            mVideoSurface.setSurfaceTextureListener(this);
        }
        mCaptureBtn.setOnClickListener(this);
    }

    private void initPreviewer() {
        BaseProduct product = MavicDragon.getProductInstance();

        if (product == null || !product.isConnected()) {
            showToast(getString(R.string.disconnected));
        } else {
            if (null != mVideoSurface) {
                mVideoSurface.setSurfaceTextureListener(this);
            }
            if (!product.getModel().equals(Model.UNKNOWN_AIRCRAFT)) {
                if (VideoFeeder.getInstance().getVideoFeeds() != null
                        && VideoFeeder.getInstance().getVideoFeeds().size() > 0) {
                    VideoFeeder.getInstance().getVideoFeeds().get(0).setCallback(mReceivedVideoDataCallBack);
                }
            }
        }
    }

    private void uninitPreviewer() {
        Camera camera = MavicDragon.getCameraInstance();
        if (camera != null){
            // Reset the callback
            VideoFeeder.getInstance().getVideoFeeds().get(0).setCallback(null);
        }
    }

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
        Log.e(TAG, "onSurfaceTextureAvailable");
        if (mCodecManager == null) {
            mCodecManager = new DJICodecManager(this, surface, width, height);
        }

    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
        Log.e(TAG, "onSurfaceTextureSizeChanged");
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
        Log.e(TAG,"onSurfaceTextureDestroyed");
        if (mCodecManager != null) {
            mCodecManager.cleanSurface();
            mCodecManager = null;
        }

        return false;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surface) {
    }

    public void showToast(final String msg) {
        runOnUiThread(new Runnable() {
            public void run() {
                Toast.makeText(MainActivity.this, msg, Toast.LENGTH_SHORT).show();
            }
        });
    }

    @Override
    public void onClick(View v) {
        switch (v.getId()) {
            case R.id.btn_capture:{
                analyzeFeed();
                break;
            }
            default:
                break;
        }
    }

    private void analyzeFeed(){
        String data;
        mBitmap = this.mVideoSurface.getBitmap();
        try {
            String result = new CSFaceDetectTask().execute().get();
            if (result == "failed") {
                mText.setText("No Face Detected");
                return;
            }
            data = "Face Detected...\nIdentifying...";
            try
            {
                JSONArray faceArray = new JSONArray(result);
                JSONObject faceData = faceArray.getJSONObject(0);
                String faceId = faceData.getString("faceId");
                String personId = new CSFaceIdentifyTask().execute(faceId).get();
                data += "\npersonId: " + personId;
                if (personId == ""){
                    mText.setText(data + "\nUnidentified Person");
                    return;
                }
                String personName = new CSFaceGetPersonTask().execute(personId).get();
                data += "\nFound " + personName;
            }
            catch(JSONException e)
            {
                mText.setText(data + "\n" + e.toString());
            }
            mText.setText(data);
        }
        catch (InterruptedException e)
        {
            e.printStackTrace();
        }
        catch (ExecutionException e)
        {
            e.printStackTrace();
        }
    }

    public class CSFaceGetPersonTask extends AsyncTask<String, Void, String> {
        @Override
        protected String doInBackground(String... strings) {
            String result = "";
            String personId = strings[0];
            HttpClient httpclient = new DefaultHttpClient();
            try {
                URIBuilder builder = new URIBuilder(cognitiveServicesBaseUrl + "/persongroups/" + cognitiveServicesPersonGroup + "/persons/" + personId);
                URI uri = builder.build();
                HttpGet request = new HttpGet(uri);
                request.setHeader("Ocp-Apim-Subscription-Key", cognitiveServicesAPIKey);
                HttpResponse response = httpclient.execute(request);
                HttpEntity entity = response.getEntity();

                if (entity != null) {
                    result = EntityUtils.toString(entity);
                }

                JSONObject personData = new JSONObject(result);
                String personName = personData.getString("name");

                return personName;
            } catch (Exception e) {
                return e.toString();
            }
        }
    }

    public class CSFaceIdentifyTask extends AsyncTask<String, Void, String> {

        @Override
        protected String doInBackground(String... strings) {
            String result = "";
            HttpClient httpclient = new DefaultHttpClient();
            try {
                URIBuilder builder = new URIBuilder(cognitiveServicesBaseUrl + "/identify");
                URI uri = builder.build();
                HttpPost request = new HttpPost(uri);

                request.setHeader("Content-Type", "application/json");
                request.setHeader("Ocp-Apim-Subscription-Key", cognitiveServicesAPIKey);

                JSONObject jsonRequest = new JSONObject();
                jsonRequest.put("personGroupId", cognitiveServicesPersonGroup);
                JSONArray faceIds = new JSONArray();
                faceIds.put(strings[0]);
                jsonRequest.put("faceIds", faceIds);
                request.setEntity(new StringEntity(jsonRequest.toString()));

                HttpResponse response = httpclient.execute(request);
                HttpEntity entity = response.getEntity();

                if (entity != null) {
                    result = EntityUtils.toString(entity);
                }

                JSONArray personData = new JSONArray(result);
                JSONObject faceMatch = personData.getJSONObject(0);
                JSONArray candidates = faceMatch.getJSONArray("candidates");
                JSONObject candidate = candidates.getJSONObject(0);

                String personId = candidate.getString("personId");

                return personId;


            } catch (Exception e) {
                return "";
            }
        }
    }

    public class CSFaceDetectTask extends AsyncTask<String, Void, String> {

        @Override
        protected String doInBackground(String... params) {
            String result = "";
            HttpClient httpclient = new DefaultHttpClient();
            try {
                URIBuilder builder = new URIBuilder(cognitiveServicesBaseUrl + "/detect");
                builder.setParameter("returnFaceId", "true");
                builder.setParameter("returnFaceLandmarks", "false");

                URI uri = builder.build();
                HttpPost request = new HttpPost(uri);

                request.setHeader("Content-Type", "application/octet-stream");
                request.setHeader("Ocp-Apim-Subscription-Key", cognitiveServicesAPIKey);

                ByteArrayOutputStream output = new ByteArrayOutputStream();
                mBitmap.compress(Bitmap.CompressFormat.JPEG, 100, output);

                request.setEntity(new ByteArrayEntity(output.toByteArray()));

                HttpResponse response = httpclient.execute(request);
                HttpEntity entity = response.getEntity();

                if (entity != null) {
                    result = EntityUtils.toString(entity);
                }

                return result;


            } catch (Exception e) {
                e.printStackTrace();
                return "failed";
            }
        }
    }

}
